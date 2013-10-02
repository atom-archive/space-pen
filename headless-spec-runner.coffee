{spawn} = require 'child_process'
path = require 'path'
express = require 'express'

app = express()
app.use(express.static(__dirname))
app.listen 3000, ->
  phantomjs = spawn 'phantomjs', [path.join(__dirname, 'phantomjs-spec-runner.coffee')], stdio: 'inherit'
  phantomjs.on 'close', (code) -> process.exit(code)
