module Utils::Debuggable
  macro included
    property? debug = false

    private def __debug(*args)
      return unless debug?
      args.each do |arg|
        print "DEBUG: "
        puts arg
      end
      puts if args.size == 0
    end

    {% verbatim do %}
    private macro __debug!(*args) # Cannot be protected because of some crystal design decision
      if debug?
        {% for arg in args %}
          print "DEBUG: "
          p!({{ arg }})
        {% end %}
      end
    end
    {% end %}
  end
end
