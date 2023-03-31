module AbstractDifferentiationForwardDiffExt

if isdefined(Base, :get_extension)
    import AbstractDifferentiation as AD
    using DiffResults: DiffResults
    using ForwardDiff: ForwardDiff
else
    import ..AbstractDifferentiation as AD
    using ..DiffResults: DiffResults
    using ..ForwardDiff: ForwardDiff
end

function AD.ForwardDiffBackend(; chunksize::Union{Val,Nothing}=nothing, tag=true)
    return AD.ForwardDiffBackend{getchunksize(chunksize), tag}()
end

tag_function(ba::AD.ForwardDiffBackend{CS,true}, f) where {CS} = f
tag_function(ba::AD.ForwardDiffBackend{CS,false}, f) where {CS} = nothing

AD.@primitive function pushforward_function(ba::AD.ForwardDiffBackend, f, xs...)
    return function pushforward(vs)
        if length(xs) == 1
            v = vs isa Tuple ? only(vs) : vs
            return (ForwardDiff.derivative(h -> f(step_toward(xs[1], v, h)), 0),)
        else
            return ForwardDiff.derivative(h -> f(step_toward.(xs, vs, h)...), 0)
        end
    end
end

AD.primal_value(x::ForwardDiff.Dual) = ForwardDiff.value(x)
AD.primal_value(x::AbstractArray{<:ForwardDiff.Dual}) = ForwardDiff.value.(x)

# these implementations are more efficient than the fallbacks

function AD.gradient(ba::AD.ForwardDiffBackend, f, x::AbstractArray)
    cfg = ForwardDiff.GradientConfig(tag_function(ba, f), x, chunk(ba, x))
    return (ForwardDiff.gradient(f, x, cfg),)
end

function AD.jacobian(ba::AD.ForwardDiffBackend, f, x::AbstractArray)
    cfg = ForwardDiff.JacobianConfig(tag_function(ba, AD.asarray ∘ f), x, chunk(ba, x))
    return (ForwardDiff.jacobian(AD.asarray ∘ f, x, cfg),)
end
function AD.jacobian(ba::AD.ForwardDiffBackend, f, x::R) where {R <: Number}
    T = typeof(ForwardDiff.Tag(tag_function(ba, f), R))
    return (ForwardDiff.extract_derivative(T, f(ForwardDiff.Dual{T}(x, one(x)))),)
end

function AD.hessian(ba::AD.ForwardDiffBackend, f, x::AbstractArray)
    cfg = ForwardDiff.HessianConfig(tag_function(ba, f), x, chunk(ba, x))
    return (ForwardDiff.hessian(f, x, cfg),)
end

function AD.value_and_gradient(ba::AD.ForwardDiffBackend, f, x::AbstractArray)
    result = DiffResults.GradientResult(x)
    cfg = ForwardDiff.GradientConfig(tag_function(ba, f), x, chunk(ba, x))
    ForwardDiff.gradient!(result, f, x, cfg)
    return DiffResults.value(result), (DiffResults.derivative(result),)
end

function AD.value_and_hessian(ba::AD.ForwardDiffBackend, f, x)
    result = DiffResults.HessianResult(x)
    cfg = ForwardDiff.HessianConfig(tag_function(ba, f), result, x, chunk(ba, x))
    ForwardDiff.hessian!(result, f, x, cfg)
    return DiffResults.value(result), (DiffResults.hessian(result),)
end

@inline step_toward(x::Number, v::Number, h) = x + h * v
# support arrays and tuples
@noinline step_toward(x, v, h) = x .+ h .* v

getchunksize(::Nothing) = Nothing
getchunksize(::Val{N}) where {N} = N

chunk(::AD.ForwardDiffBackend{Nothing}, x) = ForwardDiff.Chunk(x)
chunk(::AD.ForwardDiffBackend{N}, _) where {N} = ForwardDiff.Chunk{N}()

end # module
