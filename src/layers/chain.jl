struct DEQChain{P1,D,P2} <: AbstractExplicitContainerLayer{(:pre_deq, :deq, :post_deq)}
    pre_deq::P1
    deq::D
    post_deq::P2
end

function DEQChain(layers...)
    pre_deq, post_deq, deq, encounter_deq = [], [], nothing, false
    for l in layers
        if l isa AbstractDeepEquilibriumNetwork || l isa AbstractSkipDeepEquilibriumNetwork
            @assert !encounter_deq "Can have only 1 DEQ Layer in the Chain!!!"
            deq = l
            encounter_deq = true
            continue
        end
        push!(encounter_deq ? post_deq : pre_deq, l)
    end
    @assert encounter_deq "No DEQ Layer in the Chain!!! Maybe you wanted to use Chain"
    pre_deq = length(pre_deq) == 0 ? nothing : Chain(pre_deq...)
    post_deq = length(post_deq) == 0 ? nothing : Chain(post_deq...)
    return DEQChain(pre_deq, deq, post_deq)
end

function (deq::DEQChain{P1,D,P2})(x, ps::Union{ComponentArray,NamedTuple}, st::NamedTuple) where {P1,D,P2}
    x1, st1 = if P1 == Nothing
        x, st.pre_deq
    else
        deq.pre_deq(x, ps.pre_deq, st.pre_deq)
    end
    (x2, deq_soln), st2 = deq.deq(x1, ps.deq, st.deq)
    x3, st3 = if P2 == Nothing
        x2, st.post_deq
    else
        deq.post_deq(x2, ps.post_deq, st.post_deq)
    end
    return (x3, deq_soln), (pre_deq=st1, deq=st2, post_deq=st3)
end
