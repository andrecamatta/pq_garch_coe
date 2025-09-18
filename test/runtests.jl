#!/usr/bin/env julia

# Main test runner for COE Autocall Pricer

using Test
using Random
using Dates

# Add the src directory to the load path
push!(LOAD_PATH, "../src")

# Load the main module
include("../src/autocall_pricer.jl")
include("../src/nelson_siegel_svensson.jl")
include("../src/usd_curve.jl")

println("🧪 Running COE Autocall Pricer Tests")
println("=" * "^50")

@testset "COE Autocall Pricer Tests" begin
    # Include all test files
    include("forward_consistency_test.jl")
end

println("✅ All tests completed!")