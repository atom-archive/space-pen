describe 'jQuery extensions', ->
  describe '$.fn.preempt(eventName, handler)', ->
    [returnValue, element, events, subscription] = []

    beforeEach ->
      returnValue = undefined
      element = $("<div>")
      events = []

      element.on 'foo', -> events.push(1)
      subscription = element.preempt 'foo', ->
        events.push(2)
        returnValue
      element.on 'foo', -> events.push(3)

    it 'calls the preempting handler before all others', ->
      element.trigger 'foo'
      expect(events).toEqual [2,1,3]

      events = []
      subscription.off()
      element.trigger 'foo'
      expect(events).toEqual [1,3]

    describe 'when handler returns false', ->
      it 'does not call subsequent handlers', ->
        returnValue = false
        element.trigger 'foo'
        expect(events).toEqual [2]

    describe 'when the event is namespaced', ->
      it 'calls handler', ->
        element.preempt 'foo.bar', -> events.push(4)
        bazSubscription = element.preempt 'foo.baz', -> events.push(5)
        element.trigger 'foo'
        expect(events).toEqual [5,4,2,1,3]

        events = []
        element.trigger 'foo.bar'
        expect(events).toEqual [4]

        events = []
        element.off('.bar')
        element.trigger 'foo'
        expect(events).toEqual [5,2,1,3]

        events = []
        bazSubscription.off()
        element.trigger 'foo'
        expect(events).toEqual [2,1,3]

  describe "$.fn.scrollUp/Down/ToTop/ToBottom", ->
    it "scrolls the element in the specified way if possible", ->
      view = $$ -> @div => _.times 20, => @div('A')
      view.css(height: 100, width: 100, overflow: 'scroll')
      view.appendTo($('#jasmine-content'))

      view.scrollUp()
      expect(view.scrollTop()).toBe 0

      view.scrollDown()
      expect(view.scrollTop()).toBeGreaterThan 0
      previousScrollTop = view.scrollTop()
      view.scrollDown()
      expect(view.scrollTop()).toBeGreaterThan previousScrollTop

      view.scrollToBottom()
      expect(view.scrollTop()).not.toBeLessThan view.prop('scrollHeight') - view.height()
      previousScrollTop = view.scrollTop()
      view.scrollDown()
      expect(view.scrollTop()).toBe previousScrollTop
      view.scrollUp()
      expect(view.scrollTop()).toBeLessThan previousScrollTop
      previousScrollTop = view.scrollTop()
      view.scrollUp()
      expect(view.scrollTop()).toBeLessThan previousScrollTop

      view.scrollToTop()
      expect(view.scrollTop()).toBe 0

  describe "$.fn.handlers(eventName)", ->
    it "returns no handlers when the element does not exist", ->
      view = $('.notinthepageoranything')
      expect(view.handlers()).toEqual {}

    it "returns all registered event handlers", ->
      view = $$ -> @div('div')

      expect(view.handlers()).toEqual {}
      expect(view.handlers('blur')).toEqual []
      expect(view.handlers('focus')).toEqual []

      blurHandler1 = ->
      blurHandler2 = ->
      view.on 'blur', blurHandler1
      view.on 'blur', blurHandler2
      focusHandler1 = ->
      view.on 'focus', focusHandler1

      expect(view.handlers()['blur'][0].handler).toBe blurHandler1
      expect(view.handlers()['blur'][1].handler).toBe blurHandler2
      expect(view.handlers()['focus'][0].handler).toBe focusHandler1
      expect(view.handlers('blur')[0].handler).toBe blurHandler1
      expect(view.handlers('blur')[1].handler).toBe blurHandler2
      expect(view.handlers('focus')[0].handler).toEqual focusHandler1

  describe "$.fn.view()", ->
    it "returns the containing view", ->
      class TestView extends View
        @content: (params={}, otherArg) ->
          @div =>
            @h1 "Hello"

      view = new TestView
      expect(view.find('h1').view()).toBe view

  describe "$.fn.containingView()", ->
    it "returns the containing view", ->
      class TestView extends View
        @content: (params={}, otherArg) ->
          @div =>
            @h1 "Hello"

      view = new TestView
      expect(view.find('h1').containingView()).toBe view

      # also works for non-jQuery DOM nodes
      node = document.createElement('div')
      view.find('h1')[0].appendChild(node)
      expect($(node).containingView()).toBe view

  if document.hasFocus() # It's not currently possible to run this spec in phantomjs
    describe "$.fn.hasFocus()", ->
      it "returns true if the element is focused or contains an element that is focused", ->
        $('#jasmine-content').append $$ ->
          @div id: 'parent', tabindex: -1, =>
            @div id: 'child', tabindex: -1
        parent = $('#parent')
        child = $('#child')

        expect(parent.hasFocus()).toBe false

        parent.focus()
        expect(parent.hasFocus()).toBe true

        parent.blur()
        expect(parent.hasFocus()).toBe false

        child.focus()
        expect(parent.hasFocus()).toBe true

  describe "Event.prototype", ->
    class GrandchildView extends View
      @content: -> @div class: 'grandchild'

    class ChildView extends View
      @content: ->
        @div class: 'child', =>
          @subview 'grandchild', new GrandchildView

    class ParentView extends View
      @content: ->
        @div class: 'parent', =>
          @subview 'child', new ChildView

    [parentView, event] = []
    beforeEach ->
      parentView = new ParentView
      eventHandler = jasmine.createSpy('eventHandler')
      parentView.on 'foo', '.child', eventHandler
      parentView.child.grandchild.trigger 'foo'
      event = eventHandler.argsForCall[0][0]

    describe ".currentTargetView()", ->
      it "returns the current target's space pen view", ->
        expect(event.currentTargetView()).toBe parentView.child

    describe ".targetView()", ->
      it "returns the target's space pen view", ->
        expect(event.targetView()).toBe parentView.child.grandchild
