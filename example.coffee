class HelloView extends View
  @content: (params) ->
    @div =>
      @div params.greeting
      @label for: 'name', "What is your name? "
      @div =>
        @input name: 'name', outlet: 'name'
        @button click: 'sayHello', "That's My Name"
      @div outlet: "personalGreeting"

  initialize: (params) ->
    @greeting = params.greeting

  sayHello: ->
    @personalGreeting.html("#{@greeting}, #{@name.val()}")

$('body').append(new HelloView(greeting: "Hi there"))
