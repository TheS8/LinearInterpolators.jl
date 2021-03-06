#isdefined(:LinearInterpolators) || include("../src/LinearInterpolators.jl")

module LinearInterpolatorsKernelsTests

using LinearInterpolators.Kernels

using Compat
using Compat.Test

shortname(::Nothing) = ""
shortname(m::RegexMatch) = m.captures[1]
shortname(::Type{T}) where {T} = shortname(string(T))
shortname(str::AbstractString) =
    shortname(match(r"([_A-Za-z][_A-Za-z0-9]*)([({]|$)", str))

@testset "Kernels" begin
    offsets = (0.0, 0.1, 0.2, 0.3, 0.4)
    tol = 1e-14
    conditions = (Flat, SafeFlat)
    types = (Float16, Float32, Float64)

    for (nam, ker, sup, nrml, card) in (
        ("Box", RectangularSpline(),
         1, true, true),
        ("Triangle", LinearSpline(),
         2, true, true),
        ("Derivative of Linear B-spline", LinearSpline′(),
         2, false, false),
        ("Quadratic B-spline", QuadraticSpline(),
         3, true, false),
        ("Derivative of Quadratic B-spline", QuadraticSpline′(),
         3, false, false),
        ("Cubic B-spline", CubicSpline(SafeFlat),
         4, true, false),
        ("Derivative of Cubic B-spline", CubicSpline′(),
         4, false, false),
        ("Catmull-Rom spline", CatmullRomSpline(),
         4, true, true),
        ("Cardinal cubic spline", CardinalCubicSpline(-1),
         4, true, true),
        ("Derivative of cardinal cubic spline", CardinalCubicSpline′(-1/2),
         4, false, false),
        ("Mitchell & Netravali spline", MitchellNetravaliSpline(),
         4, true, false),
        ("Duff's tensioned B-spline", MitchellNetravaliSpline(0.5, 0),
         4, true, false),
        ("Keys's (emulated)", MitchellNetravaliSpline(0, -0.7),
         4, true, true),
        ("Keys's cardinal cubics", KeysSpline(-0.7),
         4, true, true),
        ("Lanczos 2 kernel", LanczosKernel(2),
         2, false, true),
        ("Lanczos 4 kernel", LanczosKernel(Float64,4,SafeFlat),
         4, false, true),
        ("Lanczos 6 kernel", LanczosKernel(6),
         6, false, true),
        ("Lanczos 8 kernel", LanczosKernel(8),
         8, false, true))
        name = brief(ker)
        @testset "$nam" begin
            @test isnormalized(ker) == nrml
            @test iscardinal(ker) == card
            @test length(ker) == sup
            @test length(typeof(ker)) == sup
            @test size(ker) == sup
            @test size(typeof(ker)) == sup
            for T in types
                @test eltype(T(ker)) == T
                @test eltype(typeof(T(ker))) == T
            end
            for C in conditions
                @test boundaries(C(ker)) == C
                @test boundaries(typeof(C(ker))) == C
            end
            @test shortname(summary(ker)) == shortname(typeof(ker))
            if iscardinal(ker)
                @test ker(0) == 1
                @test maximum(abs.(ker([-3,-2,-1,1,2,3]))) ≤ tol
            end

            # S is the tuple of shifts applied in getweights.
            s = ntuple(i -> ((sup + 1) >> 1) - i, sup)
            err = 0.0
            for t in offsets
                dif = ker.(t .+ s) .- Kernels.getweights(ker, t)
                err = max(err, maximum(abs.(dif)))
            end
            @test err ≤ tol
        end
    end

    # Check that type and boundaries are preserved when taking the
    # derivatives of a kernel.
    for ker in (RectangularSpline(Float32,SafeFlat),
                LinearSpline(Float32,SafeFlat),
                QuadraticSpline(Float32,SafeFlat),
                CubicSpline(Float32,SafeFlat),
                CardinalCubicSpline(Float32,-1,SafeFlat))
        kerp = ker'
        @test eltype(kerp) == eltype(ker)
        @test Kernels.boundaries(kerp) == Kernels.boundaries(ker)
    end

end

end # module
