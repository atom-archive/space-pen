if typeof require is 'function'
  _ = require 'underscore-plus'
  $ = jQuery = require '../vendor/jquery'
  Grim = require 'grim'
else
  {_, jQuery} = window
  $ = jQuery

Tags =
  'a abbr address article aside audio b bdi bdo blockquote body button canvas
   caption cite code colgroup datalist dd del details dfn dialog div dl dt em
   fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header html i
   iframe ins kbd label legend li main map mark menu meter nav noscript object
   ol optgroup option output p pre progress q rp rt ruby s samp script section
   select small span strong style sub summary sup table tbody td textarea tfoot
   th thead time title tr u ul var video area base br col command embed hr img
   input keygen link meta param source track wbr'.split /\s+/

SelfClosingTags = {}
'area base br col command embed hr img input keygen link meta param
 source track wbr'.split(/\s+/).forEach (tag) -> SelfClosingTags[tag] = true

Events =
  'blur change click dblclick error focus input keydown
   keypress keyup load mousedown mousemove mouseout mouseover
   mouseup resize scroll select submit unload'.split /\s+/

# Use native matchesSelector if available, otherwise fall back
# on jQuery.is (slower, but compatible)
docEl = document.documentElement
matches = docEl.matchesSelector || docEl.mozMatchesSelector || docEl.webkitMatchesSelector || docEl.oMatchesSelector || docEl.msMatchesSelector
matchesSelector = if matches then ((elem, selector) -> matches.call(elem[0], selector)) else ((elem, selector) -> elem.is(selector))

idCounter = 0

CustomElementPrototype = Object.create(HTMLElement::)
CustomElementPrototype.attachedCallback = -> @attached?()
CustomElementPrototype.detachedCallback = -> @detached?()

# Register globally so multiple versions of SpacePen still share the same set
# of custom elements. This prevents element re-definition. If the simple element
# API needs to change in the future we'll need a different naming scheme anyway.
window.__spacePenCustomElements ?= {}
registerElement = (tagName) ->
  customTagName = "space-pen-#{tagName}"
  window.__spacePenCustomElements[customTagName] ?=
    document.registerElement?(customTagName, prototype: Object.create(CustomElementPrototype), extends: tagName)
  customTagName

# Public: View class that extends the jQuery prototype.
#
# Extending classes must implement a `@content` method.
#
# ## Examples
#
# ```coffee
# class Spacecraft extends View
#   @content: ->
#     @div =>
#       @h1 'Spacecraft'
#       @ol =>
#         @li 'Apollo'
#         @li 'Soyuz'
#         @li 'Space Shuttle'
# ```
#
# Each view instance will have all the methods from the jQuery prototype
# available on it.
#
# ```coffee
#   craft = new Spacecraft()
#   craft.find('h1').text() # 'Spacecraft'
#   craft.appendTo(document.body) # View is now a child of the <body> tag
# ```
class View extends jQuery
  @builderStack: null

  Tags.forEach (tagName) ->
    View[tagName] = (args...) -> @currentBuilder.tag(tagName, args...)

  # Public: Add the given subview wired to an outlet with the given name
  #
  # * `name` {String} name of the subview
  # * `view` DOM element or jQuery node subview
  @subview: (name, view) ->
    @currentBuilder.subview(name, view)

  # Public: Add a text node with the given text content
  #
  # * `string` {String} text contents of the node
  @text: (string) -> @currentBuilder.text(string)

  # Public: Add a new tag with the given name
  #
  # * `tagName` {String} name of the tag like 'li', etc
  # * `args...` other arguments
  @tag: (tagName, args...) -> @currentBuilder.tag(tagName, args...)

  # Public: Add new child DOM nodes from the given raw HTML string.
  #
  # * `string` {String} HTML content
  @raw: (string) -> @currentBuilder.raw(string)

  @pushBuilder: ->
    builder = new Builder
    @builderStack ?= []
    @builderStack.push(builder)
    @currentBuilder = builder

  @popBuilder: ->
    @currentBuilder = @builderStack[@builderStack.length - 2]
    @builderStack.pop()

  @buildHtml: (fn) ->
    @pushBuilder()
    fn.call(this)
    [html, postProcessingSteps] = @popBuilder().buildHtml()

  @render: (fn) ->
    [html, postProcessingSteps] = @buildHtml(fn)
    div = document.createElement('div')
    div.innerHTML = html
    fragment = $(div.childNodes)
    step(fragment) for step in postProcessingSteps
    fragment

  element: null

  constructor: (args...) ->
    if @element?
      jQuery.fn.init.call(this, @element)
    else
      [html, postProcessingSteps] = @constructor.buildHtml -> @content(args...)
      jQuery.fn.init.call(this, html)
      throw new Error("View markup must have a single root element") if @length != 1
      @element = @[0]
      @element.attached = => @attached?()
      @element.detached = => @detached?()

    @wireOutlets(this)
    @bindEventHandlers(this)

    @element.spacePenView = this
    treeWalker = document.createTreeWalker(@element, NodeFilter.SHOW_ELEMENT)
    while element = treeWalker.nextNode()
      element.spacePenView = this

    if postProcessingSteps?
      step(this) for step in postProcessingSteps
    @initialize?(args...)

  buildHtml: (params) ->
    @constructor.builder = new Builder
    @constructor.content(params)
    [html, postProcessingSteps] = @constructor.builder.buildHtml()
    @constructor.builder = null
    postProcessingSteps

  wireOutlets: (view) ->
    for element in view[0].querySelectorAll('[outlet]')
      outlet = element.getAttribute('outlet')
      view[outlet] = $(element)
      element.removeAttribute('outlet')

    undefined

  bindEventHandlers: (view) ->
    for eventName in Events
      selector = "[#{eventName}]"
      for element in view[0].querySelectorAll(selector)
        do (element) ->
          methodName = element.getAttribute(eventName)
          element = $(element)
          element.on eventName, (event) -> view[methodName](event, element)

      if matchesSelector(view, selector)
        methodName = view[0].getAttribute(eventName)
        do (methodName) ->
          view.on eventName, (event) -> view[methodName](event, view)

    undefined

  # `pushStack` and `end` are jQuery methods that construct new wrappers.
  # we override them here to construct plain wrappers with `jQuery` rather
  # than wrappers that are instances of our view class.
  pushStack: (elems) ->
    ret = jQuery.merge(jQuery(), elems)
    ret.prevObject = this
    ret.context = @context
    ret

  end: ->
    @prevObject ? jQuery(null)

  # Public: Preempt events registered with jQuery's `::on`.
  #
  # * `eventName` A event name {String}.
  # * `handler` A {Function} to execute when the eventName is triggered.
  preempt: (eventName, handler) ->
    super(eventName, handler)

class Builder
  constructor: ->
    @document = []
    @postProcessingSteps = []

  buildHtml: ->
    [@document.join(''), @postProcessingSteps]

  tag: (name, args...) ->
    options = @extractOptions(args)

    @openTag(name, options.attributes)

    if SelfClosingTags.hasOwnProperty(name)
      if options.text? or options.content?
        throw new Error("Self-closing tag #{name} cannot have text or content")
    else
      options.content?()
      @text(options.text) if options.text
      @closeTag(name)

  openTag: (name, attributes) ->
    if @document.length is 0
      attributes ?= {}
      attributes.is ?= registerElement(name)

    attributePairs =
      for attributeName, value of attributes
        "#{attributeName}=\"#{value}\""

    attributesString =
      if attributePairs.length
        " " + attributePairs.join(" ")
      else
        ""

    @document.push "<#{name}#{attributesString}>"

  closeTag: (name) ->
    @document.push "</#{name}>"

  text: (string) ->
    escapedString = string
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    @document.push escapedString

  raw: (string) ->
    @document.push string

  subview: (outletName, subview) ->
    subviewId = "subview-#{++idCounter}"
    @tag 'div', id: subviewId
    @postProcessingSteps.push (view) ->
      view[outletName] = subview
      subview.parentView = view
      view.find("div##{subviewId}").replaceWith(subview)

  extractOptions: (args) ->
    options = {}
    for arg in args
      switch typeof(arg)
        when 'function'
          options.content = arg
        when 'string', 'number'
          options.text = arg.toString()
        else
          options.attributes = arg
    options

# jQuery extensions

$.fn.view = ->
  @[0]?.spacePenView

$.fn.views = -> @toArray().map (elt) ->
  $elt = $(elt)
  $elt.view() ? $elt

$.fn.containingView = ->
  element = @[0]
  while element?
    return view if view = element.spacePenView
    element = element.parentNode

$.fn.scrollBottom = (newValue) ->
  if newValue?
    @scrollTop(newValue - @height())
  else
    @scrollTop() + @height()

$.fn.scrollDown = ->
  @scrollTop(@scrollTop() + $(window).height() / 20)

$.fn.scrollUp = ->
  @scrollTop(@scrollTop() - $(window).height() / 20)

$.fn.scrollToTop = ->
  @scrollTop(0)

$.fn.scrollToBottom = ->
  @scrollTop(@prop('scrollHeight'))

$.fn.scrollRight = (newValue) ->
  if newValue?
    @scrollLeft(newValue - @width())
  else
    @scrollLeft() + @width()

$.fn.pageUp = ->
  @scrollTop(@scrollTop() - @height())

$.fn.pageDown = ->
  @scrollTop(@scrollTop() + @height())

$.fn.isOnDom = ->
  @closest(document.body).length is 1

$.fn.isVisible = ->
  !@isHidden()

$.fn.isHidden = ->
  # We used to check @is(':hidden'). But this is much faster than the
  # offsetWidth/offsetHeight check + all the pseudo selector mess in jquery.
  style = this[0].style

  if style.display == 'none' or not @isOnDom()
    true
  else if style.display
    false
  else
    getComputedStyle(this[0]).display == 'none'

$.fn.isDisabled = ->
  !!@attr('disabled')

$.fn.enable = ->
  @removeAttr('disabled')

$.fn.disable = ->
  @attr('disabled', 'disabled')

$.fn.insertAt = (index, element) ->
  target = @children(":eq(#{index})")
  if target.length
    $(element).insertBefore(target)
  else
    @append(element)

$.fn.removeAt = (index) ->
  @children(":eq(#{index})").remove()

$.fn.indexOf = (child) ->
  @children().toArray().indexOf($(child)[0])

$.fn.containsElement = (element) ->
  (element[0].compareDocumentPosition(this[0]) & 8) == 8

$.fn.preempt = (eventName, handler) ->
  wrappedHandler = (e, args...) ->
    if handler(e, args...) == false then e.stopImmediatePropagation()
  @on(eventName, wrappedHandler)

  eventNameWithoutNamespace = eventName.split('.')[0]
  handlers = @handlers()[eventNameWithoutNamespace] ? []
  handlers.unshift(handlers.pop())

  off: => @off(eventName, wrappedHandler)

# Public: Get the event handlers registered on an element
#
# * `eventName` The optional event name to get all handlers for.
#
# Returns an {Object} of event name keys to handler array values if an
# event name isn't specified or an array of event handlers if an event name is
# specified. This method never returns null or undefined.
$.fn.handlers = (eventName) ->
  handlers = if @length then $._data(@[0], 'events') ? {} else {}
  handlers = handlers[eventName] ? [] if arguments.length is 1
  handlers

$.fn.hasParent = ->
  @parent()[0]?

$.fn.hasFocus = ->
  @is(':focus') or @is(':has(:focus)')

$.fn.flashError = ->
  @addClass 'error'
  removeErrorClass = => @removeClass 'error'
  window.setTimeout(removeErrorClass, 300)

$.fn.trueHeight = ->
  @[0].getBoundingClientRect().height

$.fn.trueWidth = ->
  @[0].getBoundingClientRect().width

$.fn.iconSize = (size) ->
  @width(size).height(size).css('font-size', size)

$.fn.intValue = ->
  parseInt(@text())

$.Event.prototype.abortKeyBinding = ->
$.Event.prototype.currentTargetView = -> $(@currentTarget).containingView()
$.Event.prototype.targetView = -> $(@target).containingView()

# Deprecations

View::subscribe = ->
  message = "The `::subscribe` method is no longer available on SpacePen views.\n\n"

  if arguments.length is 1
    message += """
      To store multiple subscription objects for later disposal, add them to a
      `CompositeDisposable` instance (https://atom.io/docs/api/v0.150.0/CompositeDisposable)
      and call `.dispose()` on it explicitly in this view's `::detached` hook.
    """
  else
    if arguments[0]?.jquery
      message += """
        To subscribe to events on a jQuery object, use the traditional `::on` and
        `::off methods`.
      """
    else
      message += """
        To subscribe to events on an Atom object, use an explicit event-subscription
        method (starting with ::onDid* or ::onWill*).

        To collect multiple subscription objects for later disposal, add them to a
        `CompositeDisposable` instance:
        https://atom.io/docs/api/v0.150.0/CompositeDisposable

        Call `.dispose()` on your `CompositeDisposable` in this view's `::detached` hook.
      """

  throw new Error(message)

View::subscribeToCommand = ->
  throw new Error """
    The `::subscribeToCommand` method is no longer available on SpacePen views."

    Please subscribe to commands via `atom.commands.add`:
    https://atom.io/docs/api/latest/CommandRegistry#instance-add

    Collect the returned subscription objects in a CompositeDisposable:
    https://atom.io/docs/api/latest/CompositeDisposable

    Call `.dispose()` on your `CompositeDisposable` in this view's `::detached` hook.
  """

$.fn.command = (eventName, handler) ->
  throw new Error """
    The `::command` method is no longer available on SpacePen views."

    Please subscribe to commands via `atom.commands.add`:
    https://atom.io/docs/api/latest/CommandRegistry#instance-add

    Collect the returned subscription objects in a CompositeDisposable:
    https://atom.io/docs/api/latest/CompositeDisposable

    Call `.dispose()` on your `CompositeDisposable` in this view's `::detached` hook.
  """


JQueryEventAdd = jQuery.event.add
jQuery.event.add = (elem, types, handler, data, selector) ->
  if /\:/.test(types)
    Grim?.deprecate """
      Are you trying to listen for the '#{types}' Atom command with `jQuery::on`?
      `jQuery::trigger` can no longer be used to listen for Atom commands. Please
      use `atom.commands.add` instead. See the docs at
      https://atom.io/docs/api/latest/CommandRegistry#instance-add for details.
    """
  JQueryEventAdd.call(this, elem, types, handler, data, selector)


JQueryTrigger = $.fn.trigger
$.fn.trigger = (eventName, data) ->
  if typeof eventName is 'string' and /\:/.test(eventName) and eventName not in ['cursor:moved', 'selection:changed', 'editor:display-updated']
    Grim?.deprecate """
      Are you trying to dispatch the '#{eventName}' Atom command with `jQuery::trigger`?
      `jQuery::trigger` can no longer emit Atom commands as it will not correctly route
      the command to its handlers. Please use `atom.commands.dispatch` instead.
      See the docs at https://atom.io/docs/api/latest/CommandRegistry#instance-dispatch
      for details.
    """
  else
    JQueryTrigger.call(this, eventName, data)

$.fn.setTooltip = ->
  throw new Error """
    setTooltip is no longer available. Please use `atom.tooltips.add` instead.
    See the docs at https://atom.io/docs/api/latest/TooltipManager#instance-add
  """

$.fn.destroyTooltip = $.fn.hideTooltip = ->
  throw new Error """
    destroyTooltip is no longer available. Please dispose the object returned
    from  `atom.tooltips.add` instead.
    See the docs at https://atom.io/docs/api/latest/TooltipManager#instance-add
  """

# Exports

exports = exports ? this
exports.View = View
exports.jQuery = jQuery
exports.$ = $
exports.$$ = (fn) -> View.render.call(View, fn)
exports.$$$ = (fn) -> View.buildHtml.call(View, fn)[0]
