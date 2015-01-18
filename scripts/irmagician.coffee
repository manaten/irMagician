# Description:
#   IR Magician Hubot wrapper
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
{SerialPort} = require 'serialport'
async = require 'async'
config = require 'config'

class IrMagicianClient extends SerialPort
  constructor: ->
    super '/dev/ttyACM0',
      baudrate: 9600

  capture: (done) ->
    @write 'c\r\n', (err) =>
      return done err if err

      @once 'data', (buffer) =>
        #assert buffer.toString() is '...'
        @once 'data', (buffer) =>
          done null, buffer.toString()

  play: (done) ->
    @write 'p\r\n', (err) =>
      return done err if err

      @once 'data', (buffer) =>
        #assert buffer.toString() is '...'
        @once 'data', (buffer) =>
          #assert buffer.toString() is ' Done !'
          done null, buffer.toString()

  information: (n, done) ->
    @write "I,#{n}\r\n", (err) =>
      return done err if err

      @once 'data', (buffer) =>
        done null, buffer.toString()

  setLED: (n, done) ->
    @write "l,#{n}\r\n", done

  setBank: (n, done) ->
    @write "b,#{n}\r\n", done

  dumpMemory: (pos, done) ->
    @write "d,#{pos}\r\n", (err) =>
      return done err if err
      @once 'data', (buffer) =>
        done null, (parseInt buffer.toString(), 16)

  setRecordPointer: (recNumber, done) ->
    @write "n,#{recNumber}\r\n", (err) =>
      return done err if err
      @once 'data', (buffer) =>
        #assert buffer.toString() is 'OK'
        done null, buffer.toString()

  setPostScaler: (postScale, done) ->
    @write "k,#{postScale}\r\n", (err) =>
      return done err if err
      @once 'data', (buffer) =>
        #assert buffer.toString() is 'OK'
        done null, buffer.toString()

  writeData: (pos, data, done) ->
    @write "w,#{pos},#{data}\r\n", done


  save: (done) ->
    async.series
      recNumber: (done) => @information 1, done
      postScale: (done) => @information 6, done
    , (err, result) =>
      return done err if err

      recNumber = parseInt result.recNumber, 16
      postScale = parseInt result.postScale, 10

      rawX = []
      tasks = []
      [0..recNumber-1].forEach (i) =>
        bank = i / 64
        pos = i % 64
        if pos is 0
          tasks.push (done) => @setBank bank, done
        tasks.push (done) => @dumpMemory pos, (err, result) ->
          return done err if err
          rawX.push result
          done()

      async.series tasks, (err) ->
        return done err if err
        done null,
          format   : 'raw'
          freq     : 38
          data     : rawX
          postscale: postScale


  load: (data, done) ->
    tasks = []
    tasks.push (done) => @setRecordPointer data.data.length, done
    tasks.push (done) => @setPostScaler data.postscale, done

    [0..data.data.length - 1].forEach (i) =>
      bank = i / 64
      pos = i % 64
      if pos is 0
        tasks.push (done) => @setBank bank, done
      tasks.push (done) => @writeData pos, data.data[i], done
    tasks.push (done) => @play done

    async.series tasks, done


module.exports = (robot) ->
  irMagician = new IrMagicianClient

  irMagician.on 'data', (buffer) ->
    console.log 'data:', buffer.toString()

  irMagician.on 'open', ->
    robot.hear /^c(apture)?$/, (msg) ->
      irMagician.capture (err, result) ->
        msg.send result

    robot.hear /^p(lay)?$/, (msg) ->
      irMagician.play (err, result) ->
        msg.send result

    robot.hear /^l(ed)? ([01])$/, (msg) ->
      irMagician.setLED msg.match[1], (err, result) ->
        msg.send result

    robot.hear /^k (.+)$/, (msg) ->
      irMagician.setPostScaler msg.match[1], (err, result) ->
        msg.send result

    robot.hear /^save$/, (msg) ->
      irMagician.save (err, result) ->
        msg.send JSON.stringify result

    robot.hear /^load (.+)$/, (msg) ->
      data = JSON.parse msg.match[1]

      irMagician.load data, (err, result) ->
        msg.send result

    robot.router.get '/send/:id', (req, res) ->
      res.set
        'Content-Type': 'application/json'

      id = req.params.id

      if config.ir[id]?
        irMagician.load config.ir[id], (err, result) ->
          res.status(200).end JSON.stringify {id:id}
      else
        res.status(404).end JSON.stringify {}
