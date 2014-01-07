class BenchmarkView extends View
  @content: (index) ->
    @div =>
      @div "parent#{index}"
      @ul =>
        @li "child#{index}"

parent = $('#container')
startTime = Date.now()
parent.append(new BenchmarkView(i)) for i in [1..1000]
parent.prepend("Time to create 1,000 views: #{Date.now() - startTime}ms")
