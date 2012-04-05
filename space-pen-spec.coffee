describe "View", ->
  view = null

  describe "View objects", ->
    beforeEach ->
      Subview = class extends View
        @content: (params) ->
          @div =>
            @h2 { outlet: "header" }, params.title
            @div "I am a subview"

      TestView = class extends View
        @content: (attrs) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, attrs.title
            @list()
            @subview 'subview', new Subview(title: "Subview")

        @list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        initialize: (params) ->
          @initializeCalledWith = params

        foo: "bar",
        li1Clicked: ->,
        li2Keypressed: ->
        viewClicked: ->

      view = new TestView(title: "Zebra")

    describe "constructor", ->
      it "calls the content class method with the given params to produce the view's html", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "calls initialize on the view with the given params", ->
        expect(view.initializeCalledWith).toEqual(title: "Zebra")

      it "wires outlet referenecs to elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector "li.foo:contains(one)"
        expect(view.li2).toMatchSelector "li.bar:contains(two)"

      it "removes the outlet attribute from markup", ->
        expect(view.li1.attr('outlet')).toBeUndefined()
        expect(view.li2.attr('outlet')).toBeUndefined()

      it "constructs and wires outlets for subviews", ->
        expect(view.subview).toExist()
        expect(view.subview.find('h2:contains(Subview)')).toExist()
        expect(view.subview.parentView).toBe view

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

      it "makes the view object accessible via the calling 'view' method on any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

    describe "when a view is inserted within another element with jquery", ->
      [content, attachHandler, subviewAttachHandler] = []

      beforeEach ->
        attachHandler = jasmine.createSpy 'attachHandler'
        subviewAttachHandler = jasmine.createSpy 'subviewAttachHandler'
        view.on 'attach', attachHandler
        view.subview.on 'attach', subviewAttachHandler
      
      it "accepts undefined arguments as jQuery does", ->
        view.append undefined

      describe "when attached to an element that is on the DOM", ->
        beforeEach ->
          content = $('#jasmine-content')

        afterEach ->
          content.empty()

        it "triggers an 'attach' event on the view and its subviews", ->
          content.append view
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

          view.detach()
          content.empty()
          attachHandler.reset()
          subviewAttachHandler.reset()

          otherElt = $('<div>')
          content.append(otherElt)
          view.insertBefore(otherElt)
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

        describe "with multiple arguments", ->
          [view2, view3, view2Handler, view3Handler] = []

          beforeEach ->
            view2Class = class extends View
              @content: -> @div id: "view2"
            view3Class = class extends View
              @content: -> @div id: "view3"
            view2 = new view2Class
            view3 = new view3Class
            view2Handler = jasmine.createSpy 'view2Handler'
            view3Handler = jasmine.createSpy 'view3Handler'
            view2.on 'attach', view2Handler
            view3.on 'attach', view3Handler

          it "triggers an 'attach' event on all args", ->
            content.append view, [view2, view3]
            expect(attachHandler).toHaveBeenCalled()
            expect(view2Handler).toHaveBeenCalled()
            expect(view3Handler).toHaveBeenCalled()

      describe "when attached to an element that is not on the DOM", ->
        it "does not trigger an attach event", ->
          fragment = $('<div>')
          fragment.append view
          expect(attachHandler).not.toHaveBeenCalled()

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

