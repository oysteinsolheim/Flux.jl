
for T in [
    :Chain, :Parallel, :SkipConnection, :Recur  # container types
  ]
  @eval function Base.show(io::IO, m::MIME"text/plain", x::$T)
    if get(io, :typeinfo, nothing) === nothing  # e.g. top level in REPL
      _big_show(io, x)
    elseif !get(io, :compact, false)  # e.g. printed inside a Vector, but not a Matrix
      _layer_show(io, x)
    else
      show(io, x)
    end
  end
end

function _big_show(io::IO, obj, indent::Int=0)
  children = trainable(obj)
  if all(_show_leaflike, children)
    _layer_show(io, obj, indent)
  else
    println(io, " "^indent, nameof(typeof(obj)), "(")
    for c in children
      _big_show(io, c, indent+2)
    end
    if indent == 0
      print(io, ")")
      _big_finale(io, params(obj))
    else
      println(io, " "^indent, "),")
    end
  end
end

_show_leaflike(x) = isleaf(x)  # mostly follow Functors, except for:
_show_leaflike(::Tuple{Vararg{<:Number}}) = true         # e.g. stride of Conv
_show_leaflike(::Tuple{Vararg{<:AbstractArray}}) = true  # e.g. parameters of LSTMcell
_show_leaflike(::Diagonal) = true                        # appears inside LayerNorm

for T in [
    :Conv, :ConvTranspose, :CrossCor, :DepthwiseConv, :Dense,
    :BatchNorm, :LayerNorm, :InstanceNorm, :GroupNorm,
  ]
  @eval function Base.show(io::IO, m::MIME"text/plain", x::$T)
    if !get(io, :compact, false)
      _layer_show(io, x)
    else
      show(io, x)
    end
  end
end

function _layer_show(io::IO, layer, indent::Int=0)
  str = sprint(show, layer, context=io)
  print(io, " "^indent, str, indent==0 ? "" : ",")
  if !isempty(params(layer))
    print(io, " "^max(2, (indent==0 ? 20 : 39) - indent - length(str)))
    printstyled(io, "# ", underscorise(sum(length, params(layer))), " parameters"; color=:light_black)
    _nan_show(io, params(layer))
  end
  indent==0 || println(io)
end

function _big_finale(io::IO, ps)
  if length(ps) > 2
    pars = underscorise(sum(length, ps))
    bytes = Base.format_bytes(sum(sizeof, ps))
    printstyled(io, " "^19, "# Total: ", length(ps), " arrays, ", pars, " parameters, ", bytes; color=:light_black)
  end
end

# utility functions

underscorise(n::Integer) =
  join(reverse(join.(reverse.(Iterators.partition(digits(n), 3)))), '_')

function _nan_show(io::IO, x)
  if !isempty(x) && _all(iszero, x)
    printstyled(io, "  (all zero)", color=:cyan)
  elseif _any(isnan, x)
    printstyled(io, "  (some NaN)", color=:red)
  elseif _any(isinf, x)
    printstyled(io, "  (some Inf)", color=:red)
  end
end

_any(f, xs::AbstractArray{<:Number}) = any(f, xs)
# _any(f, xs::Union{Tuple,NamedTuple,Zygote.Params}) = any(x -> _any(f, x), xs)
_any(f, xs) = any(x -> _any(f, x), xs)
_any(f, x::Number) = f(x)
# _any(f, x) = false

_all(f, xs) = !_any(!f, xs)
