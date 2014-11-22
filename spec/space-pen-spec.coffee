describe "View", ->
  view = null

  describe "View objects", ->
    TestView = null

    beforeEach ->
      class Subview extends View
        @content: (params={}, otherArg) ->
          @div =>
            @h2 { outlet: "header" }, params.title + " " + otherArg
            @div "I am a subview"
            @tag 'mytag', id: 'thetag', 'Non standard tag'

        initialize: (args...) ->
          @initializeCalledWith = args

      class TestView extends View
        @content: (params={}, otherArg) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, params.title + " " + otherArg
            @list()
            @subview 'subview', new Subview(title: "Subview", 43)

        @list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        initialize: (args...) ->
          @initializeCalledWith = args

        foo: "bar",
        li1Clicked: ->,
        li2Keypressed: ->
        viewClicked: ->

      view = new TestView({title: "Zebra"}, 42)

    describe "constructor", ->
      it "calls the content class method with the given params to produce the view's html", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra 42)")).toExist()
        expect(view.find("mytag#thetag:contains(Non standard tag)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "calls initialize on the view with the given params", ->
        expect(view.initializeCalledWith).toEqual([{title: "Zebra"}, 42])

      it "wires outlet referenecs to elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector "li.foo:contains(one)"
        expect(view.li2).toMatchSelector "li.bar:contains(two)"

      it "removes the outlet attribute from markup", ->
        expect(view.li1.attr('outlet')).toBeUndefined()
        expect(view.li2.attr('outlet')).toBeUndefined()

      it "constructs and wires outlets for subviews", ->
        expect(view.subview).toExist()
        expect(view.subview.find('h2:contains(Subview 43)')).toExist()
        expect(view.subview.parentView).toBe view
        expect(view.subview.constructor.currentBuilder).toBeFalsy()
        expect(view.subview.initializeCalledWith).toEqual([{title: "Subview"}, 43])

      it "does not overwrite outlets on the superview with outlets from the subviews", ->
        expect(view.header).toMatchSelector "h1"
        expect(view.subview.header).toMatchSelector "h2"

      it "binds events for elements with event name attributes", ->
        spyOn(view, 'viewClicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'keydown'
          expect(elt).toMatchSelector "div.rootDiv"

        spyOn(view, 'li1Clicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'click'
          expect(elt).toMatchSelector 'li.foo:contains(one)'

        spyOn(view, 'li2Keypressed').andCallFake (event, elt) ->
          expect(event.type).toBe 'keypress'
          expect(elt).toMatchSelector "li.bar:contains(two)"

        view.keydown()
        expect(view.viewClicked).toHaveBeenCalled()

        view.li1.click()
        expect(view.li1Clicked).toHaveBeenCalled()
        expect(view.li2Keypressed).not.toHaveBeenCalled()

        view.li1Clicked.reset()

        view.li2.keypress()
        expect(view.li2Keypressed).toHaveBeenCalled()
        expect(view.li1Clicked).not.toHaveBeenCalled()

      it "makes the view object accessible via the ::view method on any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

      it "makes the view object accessible via the ::containingView method on child elements added after the fact", ->
        child = $('<div>')
        view.append(child)
        expect(child.view()).toBeUndefined()
        expect(child.containingView()).toBe view

      it "throws an exception if the view has more than one root element", ->
        class BadView extends View
          @content: ->
            @div id: 'one'
            @div id: 'two'

        expect(-> new BadView).toThrow("View markup must have a single root element")

      it "throws an exception if the view has no content", ->
        BadView = class extends View
          @content: -> # left blank intentionally

        expect(-> new BadView).toThrow("View markup must have a single root element")

      it "throws an exception if the view has a self closing tag with text", ->
        BadView = class extends View
          @content: ->
            @div =>
              @img 'text'

        expect(-> new BadView).toThrow("Self-closing tag img cannot have text or content")

    if document.registerElement?
      describe "when a view is attached/detached to/from the DOM", ->
        it "calls ::attached and ::detached hooks if present", ->
          content = $('#jasmine-content')
          view.attached = jasmine.createSpy('attached hook')
          view.detached = jasmine.createSpy('detached hook')
          content.append(view)
          expect(view.attached).toHaveBeenCalled()

          view.detach()
          expect(view.detached).toHaveBeenCalled()

    describe "when the view constructs a new jQuery wrapper", ->
      it "constructs instances of jQuery rather than the view class", ->
        expect(view.eq(0) instanceof jQuery).toBeTruthy()
        expect(view.eq(0) instanceof TestView).toBeFalsy()
        expect(view.end() instanceof jQuery).toBeTruthy()
        expect(view.end() instanceof TestView).toBeFalsy()

  describe "View.render (bound to $$)", ->
    it "renders a document fragment based on tag methods called by the given function", ->
      fragment = $$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()

    it "renders subviews", ->
      fragment = $$ ->
        @div =>
          @subview 'foo', $$ ->
            @div id: "subview"

      expect(fragment.find('div#subview')).toExist()
      expect(fragment.foo).toMatchSelector('#subview')

  describe "$$$", ->
    it "returns the raw HTML constructed by tag methods called by the given function (not a jQuery wrapper)", ->
      html = $$$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(typeof html).toBe 'string'
      fragment = $(html)
      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()
