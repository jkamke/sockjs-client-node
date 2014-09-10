WebSocket = require('ws')
EventEmitter = require('events').EventEmitter

class WebSocketTransport extends EventEmitter
  
  @CONNECTING = 0
  @OPEN = 1
  @CLOSING = 2
  @CLOSED = 3
  
  constructor: (url) ->
    @ws = new WebSocket url
    @ws.on 'message', @onData.bind(@)
    @ws.on 'close', =>
      @emit 'close'
    @ws.on 'heartbeat', =>
      @emit 'heartbeat'
    @ws.on 'open', ->
    @ws.on 'error', (error) =>
      @emit 'error', error
    @readyState = WebSocketTransport.CONNECTING
  
  send: (message) ->
    @ws.send JSON.stringify(message)
  
  close: ->
    @ws.close()
  
  onData: (data) ->
    type = data.slice(0, 1)
    switch type
      when 'o'
        @_dispatchOpen()
      when 'a'
        payload = JSON.parse(data.slice(1) or '[]')
        i = 0
        while i < payload.length
          @_dispatchMessage payload[i]
          i++
      when 'm'
        payload = JSON.parse(data.slice(1) or 'null')
        @_dispatchMessage payload
      when 'c'
        payload = JSON.parse(data.slice(1) or '[]')
        @_didClose payload[0], payload[1]
      when 'h'
        @_dispatchHeartbeat()

  _dispatchOpen: ->
    if @readyState is WebSocketTransport.CONNECTING
      @readyState = WebSocketTransport.OPEN
      @emit 'connection'
    else
      # The server might have been restarted, and lost track of our
      # connection.
      @_didClose 1006, 'Server lost session'

  _dispatchMessage: (data) ->
    return if @readyState isnt WebSocketTransport.OPEN
    @emit 'data', data

  _dispatchHeartbeat: (data) ->
    return if @readyState isnt WebSocketTransport.OPEN
    @emit 'heartbeat'

  _didClose: (code, reason, force) ->
    throw new Error('INVALID_STATE_ERR') if @readyState isnt WebSocketTransport.CONNECTING and @readyState isnt WebSocketTransport.OPEN and @readyState isnt WebSocketTransport.CLOSING
    if @_transport
      @_transport.close()
      @_transport = null
    @readyState = WebSocketTransport.CLOSED
    @emit 'close'

module.exports = WebSocketTransport
