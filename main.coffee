# ## External Dependencies
# ### Express
# Express is a fast application server for node
express = require 'express'
# ### Stitch
# Stitch allows we to glue together .js and .coffee files and serve them together,
# allowing the use of CommonJS's `require()` on the browser environment
stitch = require 'stitch'
uglify = require 'uglify-js'
# ## Server Initialization
# First we create a express server, then we set it up to serve static files from `/public`
server = express.createServer()
server.use express.static __dirname + '/public'
# ## API initialization
# Then we require the main api file, and wire it up with express
api = require './api/api'
api.init express, server
# ## App initialization
app = stitch.createPackage paths: ["#{__dirname}/app", "#{__dirname}/shared"]
app.compile (err, src) ->
  throw err if err
  ast = uglify.parser.parse src
  ast = uglify.uglify.ast_mangle ast
  ast = uglify.uglify.ast_squeeze ast
  bin = uglify.uglify.gen_code ast
  server.get '/', (req, res) ->
    res.send(
      """
      <!DOCTYPE html>
      <script>#{bin};require('app')</script>
      """
    )
server.listen 3000