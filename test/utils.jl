using DeepEquilibriumNetworks, LinearAlgebra, SciMLBase, Test

include("test_utils.jl")

@testset "split_and_reshape" begin
    x1 = ones(Float32, 4, 4)
    x2 = fill(0.5f0, 2, 4)
    x3 = zeros(Float32, 1, 4)

    x = vcat(x1, x2, x3)
    split_idxs = Val(cumsum((0, size(x1, 1), size(x2, 1), size(x3, 1))))
    shapes = Val((size(x1, 1), size(x2, 1), size(x3, 1)))
    x_split = DEQs.__split_and_reshape(x, split_idxs, shapes)

    @test x1 == x_split[1]
    @test x2 == x_split[2]
    @test x3 == x_split[3]

    @jet DEQs.__split_and_reshape(x, split_idxs, shapes)
end

@testset "unrolled_mode check" begin
    @test SciMLBase._unwrap_val(DEQs.__check_unrolled_mode(Val(10)))
    @test !SciMLBase._unwrap_val(DEQs.__check_unrolled_mode(Val(0)))
    @test SciMLBase._unwrap_val(DEQs.__check_unrolled_mode((; fixed_depth=Val(10))))
    @test !SciMLBase._unwrap_val(DEQs.__check_unrolled_mode((; fixed_depth=Val(0))))
end

@testset "get unrolled_mode" begin
    @test DEQs.__get_unrolled_depth(Val(10)) == 10
    @test DEQs.__get_unrolled_depth((; fixed_depth=Val(10))) == 10
end

@testset "deep equilibrium solution" begin
    sol = @test_nowarn DeepEquilibriumSolution(randn(10), randn(10), randn(10), 0.4, 10,
        nothing)
    @test_nowarn println(sol)
end
