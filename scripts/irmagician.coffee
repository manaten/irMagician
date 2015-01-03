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
_ = require 'lodash'

module.exports = (robot) ->
  irMagician = new SerialPort '/dev/ttyACM0', { baudrate: 9600 }

  block = false

  irMagician.on 'open', ->
    robot.hear /^c(apture)?$/, (msg) ->
      return if block
      block = true
      irMagician.write 'c\r\n', (err)->
        if err
          block = false
          msg.send err
          return

        irMagician.once 'data', (buffer)->
          msg.send buffer.toString()
          irMagician.once 'data', (buffer)->
            msg.send buffer.toString()
            block = false

    robot.hear /^p(lay)?$/, (msg)->
      return if block
      block = true
      irMagician.write 'p\r\n', (err)->
        if err
          block = false
          msg.send err
          return

        irMagician.once 'data', (buffer)->
          msg.send buffer.toString()
          irMagician.once 'data', (buffer)->
            msg.send buffer.toString()
            block = false


    robot.hear /save/, (msg)->
      async.series
        recNumber: (done) ->
          irMagician.write 'I,1\r\n', (err)->
            return done err if err

            irMagician.once 'data', (buffer)->
              recNumber = parseInt buffer.toString(), 16
              done null, recNumber

        postScale: (done) ->
          irMagician.write 'I,6\r\n', (err)->
            return done err if err

            irMagician.once 'data', (buffer)->
              postScale = parseInt buffer.toString(), 10
              done null, postScale
      , (err, result) ->
        return if err

        rawX = []
        tasks = []
        [0..result.recNumber-1].forEach (i)->
          bank = i / 64
          pos = i % 64

          if pos is 0
            tasks.push _.bindKey irMagician, 'write', "b,#{bank}\r\n"

          tasks.push (done)->
            irMagician.write "d,#{pos}\r\n", (err)->
              return done err if err
              irMagician.once 'data', (buffer)->
                rawX.push parseInt buffer.toString(), 16
                done null
        async.series tasks, (err)->
          msg.send JSON.stringify
            format   : 'raw'
            freq     : 38
            data     : rawX
            postscale: result.postScale

    robot.hear /^load (.+)$/, (msg)->
      data = JSON.parse msg.match[1]

      tasks = []
      tasks.push (done)->
        irMagician.write "n,#{data.data.length}\r\n", (err)->
          done err if err
          irMagician.once 'data', (buffer)->
            msg.send buffer.toString()
            done null

      tasks.push (done)->
        irMagician.write "k,#{data.postscale}\r\n", (err)->
          done err if err
          irMagician.once 'data', (buffer)->
            msg.send buffer.toString()
            done null

      [0..data.data.length-1].forEach (i)->
        bank = i / 64
        pos = i % 64

        if (pos is 0)
          tasks.push (done)->
            irMagician.write "b,#{bank}\r\n", (err)->
              return done err if err
              done null


        tasks.push (done)->
          irMagician.write "w,#{pos},#{data.data[i]}\r\n", (err)->
            return done err if err
            done null

      tasks.push (done)->
        irMagician.write 'p\r\n', (err)->
          return done err if err
          irMagician.once 'data', (buffer)->
            msg.send buffer.toString()
            done null

      async.series tasks, (err, results)->
        return

  # debug
  irMagician.on 'data', (buffer)->
    console.log buffer.toString()

  irMagician.drain ->
    console.log 'drain'
