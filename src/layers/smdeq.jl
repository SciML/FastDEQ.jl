### `SK` stands for `K` Scales.
struct MultiScaleSkipDeepEquilibriumNetworkS4{M1,M2,M3,RE1,RE2,RE3,P,A,K,S} <:
       AbstractDeepEquilibriumNetwork
    main_layers::M1
    mapping_layers::M2
    shortcut_layers::M3
    main_layers_re::RE1
    mapping_layers_re::RE2
    shortcut_layers_re::RE3
    p::P
    ordered_split_idxs::Vector{Int}
    args::A
    kwargs::K
    sensealg::S
    stats::DEQTrainingStats
end

Flux.@functor MultiScaleSkipDeepEquilibriumNetworkS4 (p,)

function MultiScaleSkipDeepEquilibriumNetworkS4(
    main_layers::Tuple,
    mapping_layers::Tuple,
    shortcut_layers::Tuple,
    solver;
    p = nothing,
    sensealg = SteadyStateAdjoint(
        autodiff = false,
        autojacvec = ZygoteVJP(),
        linsolve = LinSolveKrylovJL(rtol = 0.1f0, atol = 0.1f0),
    ),
    kwargs...,
)
    @assert length(main_layers) == 4
    for layers in mapping_layers
        @assert length(layers) == 4
    end
    @assert length(shortcut_layers) == 4

    main_layers_res = []
    mapping_layers_res = []
    shortcut_layers_res = []
    ordered_split_idxs = [0]
    c = 0
    ps = []
    for layer in main_layers
        _p, _re = Flux.destructure(layer)
        push!(main_layers_res, _re)
        push!(ps, _p)
        c += length(_p)
        push!(ordered_split_idxs, c)
    end
    for layers in mapping_layers
        layer_list = []
        for layer in layers
            _p, _re = Flux.destructure(layer)
            push!(layer_list, _re)
            if length(_p) != 0
                push!(ps, _p)
            end
            c += length(_p)
            push!(ordered_split_idxs, c)
        end
        push!(mapping_layers_res, tuple(layer_list...))
    end
    for layer in shortcut_layers
        _p, _re = Flux.destructure(layer)
        push!(shortcut_layers_res, _re)
        push!(ps, _p)
        c += length(_p)
        push!(ordered_split_idxs, c)
    end
    p = p === nothing ? vcat(ps...) : p

    return MultiScaleSkipDeepEquilibriumNetworkS4(
        main_layers,
        mapping_layers,
        shortcut_layers,
        tuple(main_layers_res...),
        tuple(mapping_layers_res...),
        tuple(shortcut_layers_res...),
        p,
        ordered_split_idxs,
        (solver,),
        kwargs,
        sensealg,
        DEQTrainingStats(0),
    )
end

function (mdeq::MultiScaleSkipDeepEquilibriumNetworkS4)(
    x::AbstractArray{T,N},
    p = mdeq.p,
) where {T,N}
    p_main, p_shortcut_1, p_shortcut_2, p_shortcut_3, p_shortcut_4 = (
        p[1:mdeq.ordered_split_idxs[end-4]],
        p[mdeq.ordered_split_idxs[end-4]+1:mdeq.ordered_split_idxs[end-3]],
        p[mdeq.ordered_split_idxs[end-3]+1:mdeq.ordered_split_idxs[end-2]],
        p[mdeq.ordered_split_idxs[end-2]+1:mdeq.ordered_split_idxs[end-1]],
        p[mdeq.ordered_split_idxs[end-1]+1:mdeq.ordered_split_idxs[end]],
    )

    initial_conditions =
        Zygote.@ignore Vector{SingleResolutionFeatures{typeof(vec(x)),T}}(
            undef,
            length(mdeq.main_layers),
        )
    sizes =
        Zygote.@ignore Vector{NTuple{N,Int64}}(undef, length(mdeq.main_layers))
    Zygote.@ignore for i = 1:length(initial_conditions)
        _x = mdeq.shortcut_layers[i](x)
        sizes[i] = size(_x)
        initial_conditions[i] = SingleResolutionFeatures(vec(_x))
    end
    u0 = Zygote.@ignore construct(MultiResolutionFeatures, initial_conditions)

    function dudt_(u, _p)
        mdeq.stats.nfe += 1

        # Yeah I know tiresome to write...
        p1 = _p[mdeq.ordered_split_idxs[1]+1:mdeq.ordered_split_idxs[2]]
        p2 = _p[mdeq.ordered_split_idxs[2]+1:mdeq.ordered_split_idxs[3]]
        p3 = _p[mdeq.ordered_split_idxs[3]+1:mdeq.ordered_split_idxs[4]]
        p4 = _p[mdeq.ordered_split_idxs[4]+1:mdeq.ordered_split_idxs[5]]
        p11 = _p[mdeq.ordered_split_idxs[5]+1:mdeq.ordered_split_idxs[6]]
        p12 = _p[mdeq.ordered_split_idxs[6]+1:mdeq.ordered_split_idxs[7]]
        p13 = _p[mdeq.ordered_split_idxs[7]+1:mdeq.ordered_split_idxs[8]]
        p14 = _p[mdeq.ordered_split_idxs[8]+1:mdeq.ordered_split_idxs[9]]
        p21 = _p[mdeq.ordered_split_idxs[9]+1:mdeq.ordered_split_idxs[10]]
        p22 = _p[mdeq.ordered_split_idxs[10]+1:mdeq.ordered_split_idxs[11]]
        p23 = _p[mdeq.ordered_split_idxs[11]+1:mdeq.ordered_split_idxs[12]]
        p24 = _p[mdeq.ordered_split_idxs[12]+1:mdeq.ordered_split_idxs[13]]
        p31 = _p[mdeq.ordered_split_idxs[13]+1:mdeq.ordered_split_idxs[14]]
        p32 = _p[mdeq.ordered_split_idxs[14]+1:mdeq.ordered_split_idxs[15]]
        p33 = _p[mdeq.ordered_split_idxs[15]+1:mdeq.ordered_split_idxs[16]]
        p34 = _p[mdeq.ordered_split_idxs[16]+1:mdeq.ordered_split_idxs[17]]
        p41 = _p[mdeq.ordered_split_idxs[17]+1:mdeq.ordered_split_idxs[18]]
        p42 = _p[mdeq.ordered_split_idxs[18]+1:mdeq.ordered_split_idxs[19]]
        p43 = _p[mdeq.ordered_split_idxs[19]+1:mdeq.ordered_split_idxs[20]]
        p44 = _p[mdeq.ordered_split_idxs[20]+1:mdeq.ordered_split_idxs[21]]

        u_prevs_1 = reshape(u.nodes[1].values, sizes[1])
        u_prevs_2 = reshape(u.nodes[2].values, sizes[2])
        u_prevs_3 = reshape(u.nodes[3].values, sizes[3])
        u_prevs_4 = reshape(u.nodes[4].values, sizes[4])

        out_1 = mdeq.main_layers_re[1](p1)(u_prevs_1, x)
        out_2 = mdeq.main_layers_re[2](p2)(u_prevs_2)
        out_3 = mdeq.main_layers_re[3](p3)(u_prevs_3)
        out_4 = mdeq.main_layers_re[4](p4)(u_prevs_4)

        u_1 =
            mdeq.mapping_layers_re[1][1](p11)(out_1) .+
            mdeq.mapping_layers_re[2][1](p21)(out_2) .+
            mdeq.mapping_layers_re[3][1](p31)(out_3) .+
            mdeq.mapping_layers_re[4][1](p41)(out_4)
        u_2 =
            mdeq.mapping_layers_re[1][2](p12)(out_1) .+
            mdeq.mapping_layers_re[2][2](p22)(out_2) .+
            mdeq.mapping_layers_re[3][2](p32)(out_3) .+
            mdeq.mapping_layers_re[4][2](p42)(out_4)
        u_3 =
            mdeq.mapping_layers_re[1][3](p13)(out_1) .+
            mdeq.mapping_layers_re[2][3](p23)(out_2) .+
            mdeq.mapping_layers_re[3][3](p33)(out_3) .+
            mdeq.mapping_layers_re[4][3](p43)(out_4)
        u_4 =
            mdeq.mapping_layers_re[1][4](p14)(out_1) .+
            mdeq.mapping_layers_re[2][4](p24)(out_2) .+
            mdeq.mapping_layers_re[3][4](p34)(out_3) .+
            mdeq.mapping_layers_re[4][4](p44)(out_4)

        return (u_1, u_2, u_3, u_4, u_prevs_1, u_prevs_2, u_prevs_3, u_prevs_4)
    end

    function dudt(u, _p, t)
        u_1, u_2, u_3, u_4, u_prevs_1, u_prevs_2, u_prevs_3, u_prevs_4 =
            dudt_(u, _p)

        return construct(
            MultiResolutionFeatures,
            [
                SingleResolutionFeatures(vec(u_1 .- u_prevs_1)),
                SingleResolutionFeatures(vec(u_2 .- u_prevs_2)),
                SingleResolutionFeatures(vec(u_3 .- u_prevs_3)),
                SingleResolutionFeatures(vec(u_4 .- u_prevs_4)),
            ],
        )
    end

    ssprob = SteadyStateProblem(dudt, u0, p_main)
    res =
        solve(
            ssprob,
            mdeq.args...;
            u0 = u0,
            sensealg = mdeq.sensealg,
            mdeq.kwargs...,
        ).u
    sol = dudt_(res, p_main)[1:4]

    guesses = (
        mdeq.shortcut_layers_re[1](p_shortcut_1)(x),
        mdeq.shortcut_layers_re[2](p_shortcut_2)(x),
        mdeq.shortcut_layers_re[3](p_shortcut_3)(x),
        mdeq.shortcut_layers_re[4](p_shortcut_4)(x),
    )

    return sol, guesses
end
