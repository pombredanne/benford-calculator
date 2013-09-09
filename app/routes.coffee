fs = require 'fs'
mongodb = require 'mongodb'

title = 'Benford&#39;s law checker'

#Connect to database
connectURL = process.env.MONGOLAB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/benford'
coll = null
mongodb.MongoClient.connect connectURL, (err, db) =>
    if not err?
        coll = db.collection 'data'

#Index page
exports.index = (req, res) =>
	res.render 'index', { title : title }

renderCheckedPage = (doc, req, res, share = yes) =>
    #Check if 2 magnitudes > 80%
    apply = yes
    doc.magnitudes.map (leftHand) =>
        doc.magnitudes.map (rightHand) =>
            if leftHand isnt rightHand and leftHand[1] + rightHand[1] >= 80
                apply = no
    locals =
        percents : doc.percents
        magnitudes : doc.magnitudes
        total : doc.total
        title : title
        law : [
            [1, 30.1]
            [2, 17.6]
            [3, 12.5]
            [4, 9.7]
            [5, 7.9]
            [6, 6.7]
            [7, 5.8]
            [8, 5.1]
            [9, 4.6]
        ]
        apply : apply

    if share
        #If the results were stored in DB, display the `share URL`
        locals.shareUrl = req.protocol + '://' + (req.get 'host') + req.url
    res.render 'checker', locals

exports.checker = (req, res) =>
    globalString = req.body.data

    #If there's uploaded file, concatenate its content with
    # req.body.data (textarea's content)
    if req.files.file.name isnt '' || Array.isArray req.files.file
        if not Array.isArray req.files.file
            req.files.file = [req.files.file]
        #If there's more than one file, we iterate trough each
        req.files.map (file) =>
            globalString += "\n" + do (fs.readFileSync file.path).toString
            fs.unlink file.path

    #Extract numbers from the text
    regex = /\d+([.,]?\d+)*/gm
    numbers = globalString.match regex

    #Get the first digit of each number
    #Compute orders of magnitudes in the same loop
    total = 0
    results = {}
    magnitudes = {0 : 0}
    lastMagnitude = 0
    results[i] = 0 for i in [1..9]
    for i of numbers
        #Remove all `,` and `.` from the number
        numbers[i] = parseInt (String numbers[i]).replace /[.,]/, ''
        if String(numbers[i])[0] > 0
            ++total
            ++results[String(numbers[i])[0]]
            #Cast number into String and use (.length - 1) as order of magnitude
            pow = parseInt (String(numbers[i]).length - 1)
            if pow > lastMagnitude
                magnitudes[j] = 0 for j in [(lastMagnitude + 1)..pow]
                lastMagnitude = pow
            ++magnitudes[String(pow)]

    #Compute %
    #(Math.round value * 10) / 10) round value to two decimals
    percents = []
    for key, value of results
        percents.push [parseInt(key),
                       (Math.round (value * 100 / total) * 10) / 10]

    #Compute magnitudes %
    #(Math.round value * 10) / 10) round value to two decimals
    magnitudePercents = []
    for key, val of magnitudes
        magnitudePercents.push [key,
                         (Math.round (magnitudes[key] * 100 / total) * 10) / 10]

    locals =
        percents : percents
        magnitudes : magnitudePercents
        total : total

    if req.body.keep == 'on'
        #Insert data in DB
        coll.insert locals, {safe : yes}, (err, item) =>
            #Finally, render the page
            res.redirect '/checker/' + item[0]._id
    else
        #Finally, render the page
        renderCheckedPage locals, req, res, no

exports.checked = (req, res) =>
    id = new mongodb.ObjectID req.params.id

    #Retrieve information from the database
    coll.findOne {_id : id}, (err, doc) =>
        if err? or not doc?
            #If the specified ID isn't valid, redirect to home page
            res.redirect '/'
        else
            #Finally, render the page
            renderCheckedPage doc, req, res