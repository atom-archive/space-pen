page = require('webpage').create()

startTime = null

isDone = ->
  page.evaluate ->
    document.querySelector('.jasmine_reporter .finished-at')?.innerText

isPassed = ->
  page.evaluate ->
    document.querySelector('.jasmine_reporter .runner.passed')?

getDescription = ->
  page.evaluate ->
    document.querySelector('.runner .description').innerText

waitUntilDone = ->
  if isDone()
    console.log getDescription()
    if isPassed()
      phantom.exit()
    else
      phantom.exit(1)
  else
    if new Date().getTime() - startTime > 60 * 1000
      console.log 'Specs timed out'
      phantom.exit(1)
    else
      setTimeout(waitUntilDone, 100)

page.open 'http://localhost:3000/', (status) ->
  startTime = new Date().getTime()
  if status is 'success'
    waitUntilDone()
  else
    phantom.exit(1)
