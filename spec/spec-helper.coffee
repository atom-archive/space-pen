window._ = require 'underscore-plus'

jasmine?.getEnv().addEqualityTester(window._.isEqual)
afterEach? -> $('#jasmine-content').empty()
