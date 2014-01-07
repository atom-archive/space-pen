# SpacePen [![Build Status](https://travis-ci.org/atom/space-pen.png?branch=master)](https://travis-ci.org/atom/space-pen)

## Write markup on the final frontier

SpacePen is a powerful but minimalist client-side view framework for
CoffeeScript. It combines the "view" and "controller" into a single jQuery
object, whose markup is expressed with an embedded DSL similar to Markaby for
Ruby.

## Basics

View objects extend from the View class and have a @content class method where
you express their HTML contents with an embedded markup DSL:

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol =>
        @li "Apollo"
        @li "Soyuz"
        @li "Space Shuttle"
```

Views descend from jQuery's prototype, so when you construct one you can call
jQuery methods on it just as you would a DOM fragment created with `$(...)`.

```coffeescript
view = new Spacecraft
view.find('ol').append('<li>Star Destroyer</li>')

view.on 'click', 'li', ->
  alert "They clicked on #{$(this).text()}"
```

But SpacePen views are more powerful than normal jQuery fragments because they
let you define custom methods:

```coffeescript
class Spacecraft extends View
  @content: -> ...

  addSpacecraft: (name) ->
    @find('ol').append "<li>#{name}</li>"


view = new Spacecraft
view.addSpacecraft "Enterprise"
```

You can also pass arguments on construction, which get passed to both the
`@content` method and the view's constructor.

```coffeescript
class Spacecraft extends View
  @content: (params) ->
    @div =>
      @h1 params.title
      @ol =>
        @li name for name in params.spacecraft

view = new Spacecraft(title: "Space Weapons", spacecraft: ["TIE Fighter", "Death Star", "Warbird"])
```

Methods from the jQuery prototype can be gracefully overridden using `super`:

```coffeescript
class Spacecraft extends View
  @content: -> ...

  hide: ->
    console.log "Hiding Spacecraft List"
    super()
```

If you override the View class's constructor, ensure you call `super`.
Alternatively, you can define an `initialize` method, which the constructor will
call for you automatically with the constructor's arguments.

```coffeescript
class Spacecraft extends View
  @content: -> ...

  initialize: (params) ->
    @title = params.title
```

## Outlets and Events

SpacePen will automatically create named reference for any element with an
`outlet` attribute. For example, if the `ol` element has an attribute
`outlet=list`, the view object will have a `list` entry pointing to a jQuery
wrapper for the `ol` element.

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol outlet: "list", =>
        @li "Apollo"
        @li "Soyuz"
        @li "Space Shuttle"

  addSpacecraft: (name) ->
    @list.append("<li>#{name}</li>")
```

Elements can also have event name attributes whose value references a custom
method. For example, if a `button` element has an attribute
`click=launchSpacecraft`, then SpacePen will invoke the `launchSpacecraft`
method on the button`s parent view when it is clicked:

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol =>
        @li click: 'launchSpacecraft', "Saturn V"

  launchSpacecraft: (event, element) ->
    console.log "Preparing #{element.name} for launch!"
```
## Markup DSL Details

### Tag Methods (`@div`, `@h1`, etc.)

As you've seen so far, the markup DSL is pretty straightforward. From the
`@content` class method or any method it calls, just invoke instance methods
named for the HTML tags you want to generate. There are 3 types of arguments you
can pass to a tag method:

* Strings
  The string will be HTML-escaped and used as the text contents of the generated tag.

* Hashes
  The key-value pairs will be used as the attributes of the generated tag.

* Functions (bound with `=>`)
  The function will be invoked in-between the open and closing tag to produce
  the HTML element's contents.

If you need to emit a non-standard tag, you can use the `@tag(name, args...)`
method to name the tag with a string:

```coffeescript
@tag 'bubble', type: "speech", => ...
```

### Text Methods

* `@text(string)`
  Emits the HTML-escaped string as text wherever it is called.

* `@raw(string)`
  Passes the given string through unescaped. Use this when you need to emit markup directly that was generated beforehand.

## Subviews

Subviews are a great way to make your view code more modular. The
`@subview(name, view)` method takes a name and another view object. The view
object will be inserted at the location of the call, and a reference with the
given name will be wired to it from the parent view. A `parentView` reference
will be created on the subview pointing at the parent.

```coffeescript
class Spacecraft extends View
  @content: (params) ->
    @div =>
      @subview 'launchController', new LaunchController(countdown: params.countdown)
      @h1 "Spacecraft"
      ...
```

## Freeform Markup Generation

You don't need a View class to use the SpacePen markup DSL. Call `View.render`
with an unbound function (`->`, not `=>`) that calls tag methods, and it will
return a document fragment for ad-hoc use. This method is also assigned to the
`$$` global variable for convenience.

```coffeescript
view.list.append $$ ->
  @li =>
    @text "Starship"
    @em "Enterprise"
```

## jQuery extensions

### $.fn.view
You can retrieve the view object for any DOM element by calling `view()` on it.
This usually shouldn't be necessary, as most DOM manipulation will take place
within the view itself using outlet references, but is occasionally helpful.

```coffeescript
view = new Spacecraft
$('body').append(view)

# assuming no other li elements on the DOM, for example purposes,
# the following expression should be true
$('li').view() == view
```

### After Attach Hooks
The `initialize` method is always called when the view is still a detached DOM
fragment, before it is appended to the DOM. This is usually okay, but
occasionally you'll have some initialization logic that depends on the view
actually being on the DOM. For example, you may depend on applying a CSS rule
before measuring an element's height.

SpacePen extends jQuery manipulation methods like `append`, `replaceWith`, etc.
to call `afterAttach` hooks on your view objects when they are appended to other
elements. The hook will be called with a boolean value indicating whether the
view is attached to the main DOM or just to another DOM fragment. If
`afterAttach` is called with `true`, you can assume your object is attached to
the page.

```coffeescript
class Spacecraft extends View
  @content: -> ...

  afterAttach: (onDom) ->
    if onDom
      console.log "With CSS applied, my height is", @height()
    else
      console.log "I just attached to", @parent()
```

### Before Remove Hooks
SpacePen calls the `beforeRemove` hook whenever a view is removed from the DOM
via a jQuery method. This works if the view is removed directly with `remove` or
indirectly when a method like `empty` or `html` is called on a parent element.
This is a good place to clean up subscriptions and other view-specific state.

```coffeescript
class Spacecraft extends View
  @content: -> ...

  initialize: ->
    $(window).on 'resize.spacecraft', -> ...

  beforeRemove: ->
    $(window).off('.spacecraft')
```

## Anticipated Concerns / Objections

### What about the view/controller distinction?
MVC was invented in a setting where graphics rendering was substantially more
complex than it is in a web browser. In Cocoa development, for example, a view
object's primary role is to implement `drawRect` and forward UI events to the
controller. But in a browser, you don't need to handle your own rendering with
`drawRect`. Instead, you express the view declaratively using markup and CSS,
and the browser takes care of the rest. The closest thing to a MVC "view" in
this world is a fragment of markup, but this contains very little logic. On the
web, the view/controller distinction is like a vestigial organ: It's a solution
to a problem we no longer have, and no longer justifies the conceptual overhead
of using two objects where one would do.

### Our designers can't handle writing markup in CoffeeScript
Okay. SpacePen might not be the right fit for you. But are you sure they can't
handle it? What if you pair with them for a couple hours and teach them what to
do? There's also the potential of plugging in another template language for
content generation, while keeping the rest of the framework. But if developers
are writing the majority of the markup, expressing it directly in CoffeeScript
is a productivity win.


## Hacking on SpacePen

```sh
git clone https://github.com/atom/space-pen.git
cd space-pen
npm install
npm start
```

* Open http://localhost:1337 to run the specs
* Open http://localhost:1337/benchmark to run the benchmarks
* Open http://localhost:1337/examples to browse the examples
