module AbstractDifferentiationChainRulesCoreExt

import AbstractDifferentiation as AD
using ChainRulesCore: ChainRulesCore

AD.@primitive function pullback_function(ba::AD.ReverseRuleConfigBackend, f, xs...)
    config = AD.ruleconfig(ba)
    _, back = ChainRulesCore.rrule_via_ad(config, f, xs...)
    function pullback(vs)
        grad = Base.tail(back(vs))
        config.context.cache = nothing
        grad
    end
    pullback(vs::Tuple{Any}) = pullback(first(vs))
    return pullback
end

end # module
