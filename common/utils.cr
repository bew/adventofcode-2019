module Utils::Debuggable
  macro included
    property? debug = false
    property? debug_id : String? = nil

    private def __debug(*args)
      return unless debug?
      args.each do |arg|
        if @debug_id
          print "DEBUG (#{@debug_id}): "
        else
          print "DEBUG: "
        end
        puts arg
      end
      puts if args.size == 0
    end

    {% verbatim do %}
    private macro __debug!(*args) # Cannot be protected because of some crystal design decision
      if debug?
        {% for arg in args %}
          if @debug_id
            print "DEBUG (#{@debug_id}): "
          else
            print "DEBUG: "
          end
          p!({{ arg }})
        {% end %}
      end
    end
    {% end %}
  end
end
