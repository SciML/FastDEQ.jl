"""
    DeepEquilibriumSolution(z_star, u₀, residual, jacobian_loss, nfe, solution)

Stores the solution of a DeepEquilibriumNetwork and its variants.

## Fields

  - `z_star`: Steady-State or the value reached due to maxiters
  - `u0`: Initial Condition
  - `residual`: Difference of the ``z^*`` and ``f(z^*, x)``
  - `jacobian_loss`: Jacobian Stabilization Loss (see individual networks to see how it
    can be computed)
  - `nfe`: Number of Function Evaluations
  - `original`: Original Internal Solution
"""
@concrete struct DeepEquilibriumSolution
    z_star
    u0
    residual
    jacobian_loss
    nfe::Int
    original
end

function DeepEquilibriumSolution()
    return DeepEquilibriumSolution(ntuple(Returns(nothing), 4)..., 0, nothing)
end

function Base.show(io::IO, sol::DeepEquilibriumSolution)
    println(io, "DeepEquilibriumSolution")
    println(io, " * Initial Guess: ", sol.u0)
    println(io, " * Steady State: ", sol.z_star)
    println(io, " * Residual: ", sol.residual)
    println(io, " * Jacobian Loss: ", sol.jacobian_loss)
    print(io, " * NFE: ", sol.nfe)
end

# Core Model
@concrete struct DeepEquilibriumNetwork{pType} <:
                 AbstractExplicitContainerLayer{(:model, :init)}
    init
    model
    solver
    jacobian_regularization
    kwargs
end

@truncate_stacktrace DeepEquilibriumNetwork 3 2

const DEQ = DeepEquilibriumNetwork

constructorof(::Type{<:DEQ{pType}}) where {pType} = DEQ{pType}

function Lux.initialstates(rng::AbstractRNG, deq::DEQ)
    rng = Lux.replicate(rng)
    randn(rng, 1)
    return (; model=Lux.initialstates(rng, deq.model), fixed_depth=Val(0),
        init=Lux.initialstates(rng, deq.init), solution=DeepEquilibriumSolution(), rng)
end

(deq::DEQ)(x, ps, st::NamedTuple) = deq(x, ps, st, __check_unrolled_mode(st))

## Pretraining
function (deq::DEQ)(x, ps, st::NamedTuple, ::Val{true})
    z, st = __get_initial_condition(deq, x, ps, st)
    repeated_model = RepeatedLayer(deq.model; repeats=st.fixed_depth)

    zˢᵗᵃʳ, st_ = repeated_model((z, x), ps.model, st.model)
    model = Lux.Experimental.StatefulLuxLayer(deq.model, ps.model, st_)
    resid = CRC.ignore_derivatives(zˢᵗᵃʳ .- model((zˢᵗᵃʳ, x)))

    rng = Lux.replicate(st.rng)
    jac_loss = __estimate_jacobian_trace(__getproperty(deq, Val(:jacobian_regularization)),
        model, ps.model, zˢᵗᵃʳ, x, rng)

    solution = DeepEquilibriumSolution(zˢᵗᵃʳ, z, resid, zero(eltype(x)),
        _unwrap_val(st.fixed_depth), nothing)
    res = __split_and_reshape(zˢᵗᵃʳ, __getproperty(deq.model, Val(:split_idxs)),
        __getproperty(deq.model, Val(:scales)))

    return res, (; st..., model=model.st, solution, rng)
end

function (deq::DEQ{pType})(x, ps, st::NamedTuple, ::Val{false}) where {pType}
    z, st = __get_initial_condition(deq, x, ps, st)

    model = Lux.Experimental.StatefulLuxLayer(deq.model, nothing, st.model)

    dudt(u, p, t) = model((u, p.x), p.ps) .- u

    prob = __construct_prob(pType, ODEFunction{false}(dudt), z, (; ps=ps.model, x))
    alg = __normalize_alg(deq)
    sol = solve(prob, alg; sensealg=__default_sensealg(prob), abstol=1e-3, reltol=1e-3,
        termination_condition=AbsNormTerminationMode(), maxiters=100, deq.kwargs...)
    zˢᵗᵃʳ = __get_steady_state(sol)

    rng = Lux.replicate(st.rng)
    jac_loss = __estimate_jacobian_trace(__getproperty(deq, Val(:jacobian_regularization)),
        model, ps.model, zˢᵗᵃʳ, x, rng)

    solution = DeepEquilibriumSolution(zˢᵗᵃʳ, z, __getproperty(sol, Val(:resid)), jac_loss,
        __get_nfe(sol), sol)
    res = __split_and_reshape(zˢᵗᵃʳ, __getproperty(deq.model, Val(:split_idxs)),
        __getproperty(deq.model, Val(:scales)))

    return res, (; st..., model=model.st, solution, rng)
end

## Constructors
"""
    DeepEquilibriumNetwork(model, solver; init = missing, jacobian_regularization=nothing,
        problem_type::Type{pType}=SteadyStateProblem{false}, kwargs...)

Deep Equilibrium Network as proposed in [baideep2019](@cite) and [pal2022mixing](@cite).

## Arguments

  - `model`: Neural Network.
  - `solver`: Solver for the rootfinding problem. ODE Solvers and Nonlinear Solvers are both
    supported.

## Keyword Arguments

  - `init`: Initial Condition for the rootfinding problem. If `nothing`, the initial
    condition is set to `zero(x)`. If `missing`, the initial condition is set to
    `WrappedFunction(zero)`. In other cases the initial condition is set to
    `init(x, ps, st)`.
  - `jacobian_regularization`: Must be one of `nothing`, `AutoFiniteDiff` or `AutoZygote`.
  - `problem_type`: Provides a way to simulate a Vanilla Neural ODE by setting the
    `problem_type` to `ODEProblem`. By default, the problem type is set to
    `SteadyStateProblem`.
  - `kwargs`: Additional Parameters that are directly passed to `SciMLBase.solve`.

## Example

```julia
using DeepEquilibriumNetworks, Lux, Random, OrdinaryDiffEq

model = DeepEquilibriumNetwork(Parallel(+, Dense(2, 2; use_bias=false),
        Dense(2, 2; use_bias=false)), VCABM3(); save_everystep=true)

rng = Random.default_rng()
ps, st = Lux.setup(rng, model)

model(rand(rng, Float32, 2, 1), ps, st)
```

See also: [`SkipDeepEquilibriumNetwork`](@ref), [`MultiScaleDeepEquilibriumNetwork`](@ref),
[`MultiScaleSkipDeepEquilibriumNetwork`](@ref).
"""
function DeepEquilibriumNetwork(model, solver; init=missing,
        jacobian_regularization=nothing,
        problem_type::Type{pType}=SteadyStateProblem{false}, kwargs...) where {pType}
    model isa AbstractExplicitLayer || (model = Lux.transform(model))

    if init === missing # Regular DEQ
        init = WrappedFunction(Base.Fix1(__zeros_init, __getproperty(model, Val(:scales))))
    elseif init === nothing # SkipRegDEQ
        init = nothing
    elseif !(init isa AbstractExplicitLayer)
        init = Lux.transform(init)
    end
    return DeepEquilibriumNetwork{pType}(init, model, solver, jacobian_regularization,
        kwargs)
end

"""
    SkipDeepEquilibriumNetwork(model, [init=nothing,] solver; kwargs...)

Skip Deep Equilibrium Network as proposed in [pal2022mixing](@cite). Alias which creates
a [`DeepEquilibriumNetwork`](@ref) with `init` kwarg set to passed value.
"""
function SkipDeepEquilibriumNetwork(model, init, solver; kwargs...)
    return DeepEquilibriumNetwork(model, solver; init, kwargs...)
end

function SkipDeepEquilibriumNetwork(model, solver; kwargs...)
    return DeepEquilibriumNetwork(model, solver; init=nothing, kwargs...)
end

## MultiScale DEQ
"""
    MultiScaleDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,
        post_fuse_layer::Union{Nothing, Tuple}, solver,
        scales::NTuple{N, NTuple{L, Int64}}; kwargs...)

Multi Scale Deep Equilibrium Network as proposed in [baimultiscale2020](@cite).

## Arguments

  - `main_layers`: Tuple of Neural Networks. Each Neural Network is applied to the
    corresponding scale.
  - `mapping_layers`: Matrix of Neural Networks. Each Neural Network is applied to the
    corresponding scale and the corresponding layer.
  - `post_fuse_layer`: Neural Network applied to the fused output of the main layers.
  - `solver`: Solver for the rootfinding problem. ODE Solvers and Nonlinear Solvers are both
    supported.
  - `scales`: Scales of the Multi Scale DEQ. Each scale is a tuple of integers. The length
    of the tuple is the number of layers in the corresponding main layer.

For keyword arguments, see [`DeepEquilibriumNetwork`](@ref).

## Example

```julia
using DeepEquilibriumNetworks, Lux, Random, OrdinaryDiffEq

main_layers = (Parallel(+, Dense(4 => 4, tanh; use_bias=false),
        Dense(4 => 4, tanh; use_bias=false)), Dense(3 => 3, tanh), Dense(2 => 2, tanh),
    Dense(1 => 1, tanh))

mapping_layers = [NoOpLayer() Dense(4 => 3, tanh) Dense(4 => 2, tanh) Dense(4 => 1, tanh);
    Dense(3 => 4, tanh) NoOpLayer() Dense(3 => 2, tanh) Dense(3 => 1, tanh);
    Dense(2 => 4, tanh) Dense(2 => 3, tanh) NoOpLayer() Dense(2 => 1, tanh);
    Dense(1 => 4, tanh) Dense(1 => 3, tanh) Dense(1 => 2, tanh) NoOpLayer()]

model = MultiScaleDeepEquilibriumNetwork(main_layers, mapping_layers, nothing, VCAB3(),
    ((4,), (3,), (2,), (1,)))

rng = Random.default_rng()
ps, st = Lux.setup(rng, model)
x = rand(rng, Float32, 4, 12)

model(x, ps, st)
```
"""
function MultiScaleDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,
        post_fuse_layer::Union{Nothing, Tuple}, solver,
        scales::NTuple{N, NTuple{L, Int64}}; kwargs...) where {N, L}
    l1 = Parallel(nothing, main_layers...)
    l2 = BranchLayer(Parallel.(+, map(x -> tuple(x...), eachrow(mapping_layers))...)...)

    scales = Val(scales)
    split_idxs = Val(Tuple(vcat(0, cumsum(prod.(_unwrap_val(scales)))...)))

    if post_fuse_layer === nothing
        model = MultiScaleInputLayer(Chain(l1, l2), split_idxs, scales)
    else
        model = MultiScaleInputLayer(Chain(l1, l2, Parallel(nothing, post_fuse_layer...)),
            split_idxs, scales)
    end

    return DeepEquilibriumNetwork(model, solver; kwargs...)
end

"""
    MultiScaleSkipDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,
        post_fuse_layer::Union{Nothing, Tuple}, [init = nothing,] solver,
        scales::NTuple{N, NTuple{L, Int64}}; kwargs...)

Skip Multi Scale Deep Equilibrium Network as proposed in [pal2022mixing](@cite). Alias which
creates a [`MultiScaleDeepEquilibriumNetwork`](@ref) with `init` kwarg set to passed value.

If `init` is not passed, it creates a MultiScale Regularized Deep Equilibrium Network.
"""
function MultiScaleSkipDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,
        post_fuse_layer::Union{Nothing, Tuple}, init::Tuple, solver,
        scales::NTuple{N, NTuple{L, Int64}}; kwargs...) where {N, L}
    init = Chain(Parallel(nothing, init...), x -> mapreduce(__flatten, vcat, x))
    return MultiScaleDeepEquilibriumNetwork(main_layers, mapping_layers, post_fuse_layer,
        solver, scales; init, kwargs...)
end

function MultiScaleSkipDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,
        post_fuse_layer::Union{Nothing, Tuple}, args...; kwargs...)
    return MultiScaleDeepEquilibriumNetwork(main_layers, mapping_layers, post_fuse_layer,
        args...; init=nothing, kwargs...)
end

"""
    MultiScaleNeuralODE(args...; kwargs...)

Same arguments as [`MultiScaleDeepEquilibriumNetwork`](@ref) but sets `problem_type` to
`ODEProblem{false}`.
"""
function MultiScaleNeuralODE(args...; kwargs...)
    return MultiScaleDeepEquilibriumNetwork(args...; kwargs...,
        problem_type=ODEProblem{false})
end

## Generate Initial Condition
@inline function __get_initial_condition(deq::DEQ{pType, Nothing}, x, ps, st) where {pType}
    zₓ = __zeros_init(__getproperty(deq.model, Val(:scales)), x)
    z, st_ = deq.model((zₓ, x), ps.model, st.model)
    return z, (; st..., model=st_)
end

@inline function __get_initial_condition(deq::DEQ, x, ps, st)
    z, st_ = deq.init(x, ps.init, st.init)
    return z, (; st..., init=st_)
end

# Other Layers
@concrete struct MultiScaleInputLayer{N, M <: AbstractExplicitLayer} <:
                 AbstractExplicitContainerLayer{(:model,)}
    model::M
    split_idxs
    scales
end

constructorof(::Type{<:MultiScaleInputLayer{N}}) where {N} = MultiScaleInputLayer{N}
Lux.display_name(::MultiScaleInputLayer{N}) where {N} = "MultiScaleInputLayer{scales = $N}"

@truncate_stacktrace MultiScaleInputLayer 1 2

function MultiScaleInputLayer(model, split_idxs, scales::Val{S}) where {S}
    return MultiScaleInputLayer{length(S)}(model, split_idxs, scales)
end

@generated function (m::MultiScaleInputLayer{N})(z, ps, st) where {N}
    inputs = (:((u_[1], x)), (:(u_[$i]) for i in 2:N)...)
    return quote
        u, x = z
        u_ = __split_and_reshape(u, m.split_idxs, m.scales)
        u_res, st = Lux.apply(m.model, ($(inputs...),), ps, st)
        return mapreduce(__flatten, vcat, u_res), st
    end
end
