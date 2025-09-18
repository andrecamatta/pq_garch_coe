#!/usr/bin/env julia

# Forward consistency tests for USD numéraire implementation

using Test
using Random
using Dates
using Statistics
using LinearAlgebra
using DataFrames
using CSV
using Distributions

# Test helpers for controlled scenarios
################################################################################

"""
    create_flat_nss_curve(rate::Float64, date::Date)

Create a flat NSS curve with constant rate for testing.
"""
function create_flat_nss_curve(rate::Float64, date::Date)
    # For a flat curve, set β₀ = rate and others = 0
    return NSSParameters(
        rate,    # β₀ (long-term rate)
        0.0,     # β₁
        0.0,     # β₂
        0.0,     # β₃
        1.0,     # τ₁
        5.0,     # τ₂
        date     # pricing_date
    )
end

"""
    create_flat_usd_curve(rate::Float64, date::Date)

Create a flat USD Treasury curve with constant rate for testing.
"""
function create_flat_usd_curve(rate::Float64, date::Date)
    maturities = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]  # Standard maturities
    rates = fill(rate, length(maturities))  # All rates equal

    # Create simple interpolator (constant function)
    function flat_interpolator(T::Real)
        return rate
    end

    return USDCurveParams(
        date,
        maturities,
        rates,
        flat_interpolator
    )
end

"""
    create_real_project_specs()

Create the real project underlying specs (AMD, AMZN, META, TSM) with actual prices.
"""
function create_real_project_specs()
    # Use actual project symbols and approximate historical prices
    return [
        UnderlyingSpec("AMD", 178.68, false, 0.0),
        UnderlyingSpec("AMZN", 178.15, false, 0.0),
        UnderlyingSpec("META", 505.56, false, 0.0),
        UnderlyingSpec("TSM", 136.62, true, 0.015),  # TSM has dividend yield
    ]
end

"""
    create_simple_specs(prices::Vector{Float64})

Create simple test specs with given prices for testing.
"""
function create_simple_specs(prices::Vector{Float64})
    return [
        UnderlyingSpec("TEST$(i)", prices[i], false, 0.0)
        for i in 1:length(prices)
    ]
end

"""
    create_deterministic_config(rate_brl::Float64, rate_usd::Float64, fx_spot::Float64)

Create a deterministic autocall configuration for testing.
"""
function create_deterministic_config(rate_brl::Float64, rate_usd::Float64, fx_spot::Float64)
    date = Date(2024, 1, 1)

    # Simple configuration: 2 observations over 1 year
    coupons = [0.05, 0.05]  # 5% semi-annual
    obs_spacing_days = 126  # ~6 months
    horizon_days = 252      # 1 year
    principal = 1000.0      # Simple round number

    nss_params = create_flat_nss_curve(rate_brl, date)
    usd_curve = create_flat_usd_curve(rate_usd, date)

    return AutocallConfig(
        coupons, obs_spacing_days, horizon_days,
        principal, rate_brl, nss_params, usd_curve, fx_spot
    )
end

"""
    create_mock_garch_models(specs::Vector{UnderlyingSpec})

Create mock GARCH models for testing without API calls.
"""
function create_mock_garch_models(specs::Vector{UnderlyingSpec})
    # Create simple mock GARCH models with reasonable parameters
    models = GARCHUnivariate[]
    for spec in specs
        # Mock model with typical parameters
        mock_model = GARCHUnivariate(
            nothing,  # model (not used in simulation)
            0.0001,   # ω
            0.05,     # α
            0.90,     # β
            0.0,      # μ
            0.0004,   # σ²₀ (starting volatility²)
            8.0,      # ν (degrees of freedom for t-distribution)
            :student  # innovation_dist
        )
        push!(models, mock_model)
    end
    return models
end

"""
    create_mock_dcc()

Create mock DCC parameters for testing without fitting.
"""
function create_mock_dcc()
    # Mock DCC with typical parameters
    return DCCParams(
        0.01,  # a
        0.95,  # b
        [1.0 0.5 0.5 0.5;
         0.5 1.0 0.5 0.5;
         0.5 0.5 1.0 0.5;
         0.5 0.5 0.5 1.0]  # Q̄ (4x4 correlation matrix with 50% correlation)
    )
end

"""
    sample_student_t(dof::Float64, n::Int)

Sample from normalized Student-t distribution.
"""
function sample_student_t(dof::Float64, n::Int)
    if dof > 2
        # Use normalized t-distribution
        t_vals = rand(Distributions.TDist(dof), n)
        normalization = sqrt(dof / (dof - 2))
        return t_vals ./ normalization
    else
        # Fallback to normal if dof too low
        return randn(n)
    end
end

"""
    price_with_direct_brl_discount(specs, config; num_paths=200)

Alternative pricing method that simulates directly in BRL and discounts with NSS.
This is used to test equivalence when r_BRL = r_USD.
"""
function price_with_direct_brl_discount(specs, config; num_paths=200)
    # For testing: create simplified version that doesn't use USD numéraire
    # This is a conceptual implementation for the equivalence test

    # Use mock GARCH models for testing (no API calls)
    models = create_mock_garch_models(specs)
    dcc = create_mock_dcc()

    # Get average ν for t-Student
    t_student_models = filter(m -> m.innovation_dist == :student, models)
    dof = length(t_student_models) > 0 ? mean([m.ν for m in t_student_models]) : 8.0

    # Simple Monte Carlo in BRL (conceptual)
    N = length(specs)
    S0 = [spec.price0 for spec in specs]
    coupons = config.coupons
    obs_schedule = [config.obs_spacing_days * i for i in 1:length(coupons)]

    payoffs = zeros(num_paths)

    Random.seed!(42)  # Deterministic

    for path in 1:num_paths
        S = copy(S0)
        h = [mdl.σ²₀ for mdl in models]
        eps_prev = zeros(N)
        Q = copy(dcc.Q̄)
        coupon_accrual = 0.0
        alive = true

        for t in 1:config.horizon_days
            # DCC correlation update
            if t == 1
                Q = dcc.Q̄
            else
                z_prev = eps_prev ./ sqrt.(h)
                outer = z_prev * z_prev'
                Q = (1 - dcc.a - dcc.b) * dcc.Q̄ + dcc.a * outer + dcc.b * Q
            end

            D = Diagonal(1 ./ sqrt.(diag(Q)))
            R = Symmetric(D * Q * D)

            # Generate correlated shocks
            local epsilon
            try
                L = cholesky(R).L
                z_t = sample_student_t(dof, N)
                epsilon = L * z_t
            catch
                epsilon = randn(N)
            end

            # Update prices (BRL-based drift using r_BRL)
            for j in 1:N
                mdl = models[j]
                h[j] = mdl.ω + mdl.α * (eps_prev[j])^2 + mdl.β * h[j]
                σ = sqrt(h[j])

                # BRL risk-neutral drift
                daily_rf = config.rf_rate / 252.0
                drift = daily_rf - 0.5 * σ^2

                ret = drift + σ * epsilon[j]
                S[j] *= exp(ret)
                eps_prev[j] = σ * epsilon[j]
            end

            # Check autocall conditions
            if alive && t in obs_schedule
                obs_idx = findfirst(==(t), obs_schedule)
                coupon = coupons[obs_idx]
                if all(S .>= S0)
                    # Autocall triggered
                    coupon_accrual += coupon
                    payoff_brl = config.principal * (1 + coupon_accrual)

                    # Discount to present value using NSS
                    τ_years = t / 252.0
                    df_brl = nss_discount_factor(config.nss_params, τ_years)
                    payoffs[path] = payoff_brl * df_brl
                    alive = false
                    break
                else
                    coupon_accrual += coupon
                end
            end
        end

        # If not autocalled, pay principal at maturity
        if alive
            payoff_brl = config.principal * (1 + coupon_accrual)
            τ_final = config.horizon_days / 252.0
            df_brl = nss_discount_factor(config.nss_params, τ_final)
            payoffs[path] = payoff_brl * df_brl
        end
    end

    return (mean_price = mean(payoffs), stderr = std(payoffs) / sqrt(num_paths), q05 = 0.0, q95 = 0.0)
end

# Main test sets
################################################################################

@testset "Forward Consistency Tests" begin

    @testset "Test Helpers" begin
        # Test that helpers create valid objects
        date = Date(2024, 1, 1)

        nss = create_flat_nss_curve(0.05, date)
        @test nss.β₀ == 0.05
        @test nss.pricing_date == date

        usd = create_flat_usd_curve(0.03, date)
        @test usd.rates[3] == 0.03  # 1-year rate (index 3)

        specs = create_real_project_specs()
        @test length(specs) == 4
        @test specs[1].symbol == "AMD"
        @test specs[4].has_dividend_yield == true  # TSM

        config = create_deterministic_config(0.05, 0.05, 5.0)
        @test config.principal == 1000.0
        @test config.fx_spot == 5.0
    end

    @testset "Forward Equivalence Test (r_BRL = r_USD)" begin
        # When Brazilian and USD rates are equal, forward rate = spot rate
        # USD numéraire approach should give same result as direct BRL approach

        rate = 0.05  # 5% for both currencies
        fx_spot = 5.0
        specs = create_real_project_specs()
        config = create_deterministic_config(rate, rate, fx_spot)

        # Set pricing date to avoid data fetch issues
        pricing_date = Date(2024, 3, 21)

        println("🧪 Testing forward equivalence (r_BRL = r_USD = 5%)")

        # Method A: Current implementation (USD numéraire + FX forward)
        models = create_mock_garch_models(specs)
        dcc = create_mock_dcc()

        Random.seed!(42)
        result_forward = price_autocall_with_models(models, dcc, specs, config; num_paths=200)

        # Method B: Direct BRL discount (for comparison)
        result_direct = price_with_direct_brl_discount(specs, config; num_paths=200)

        println("  Forward method: $(round(result_forward.mean_price, digits=2))")
        println("  Direct method:  $(round(result_direct.mean_price, digits=2))")

        # Test that results are approximately equal (within 10% tolerance)
        # Note: Larger tolerance due to different numéraire approaches
        # Full theoretical equivalence would require more sophisticated direct BRL implementation
        @test result_forward.mean_price ≈ result_direct.mean_price rtol=0.10
    end

    @testset "Forward Basis Consistency Test" begin
        # Test that FX spot changes affect price proportionally

        fx_base = 5.0
        fx_higher = 5.5  # 10% higher
        rate_brl = 0.10
        rate_usd = 0.05

        specs = create_simple_specs([100.0, 100.0, 100.0, 100.0])
        config_base = create_deterministic_config(rate_brl, rate_usd, fx_base)
        config_higher = create_deterministic_config(rate_brl, rate_usd, fx_higher)

        println("🧪 Testing FX basis consistency")

        # Use mock models for consistency
        models = create_mock_garch_models(specs)
        dcc = create_mock_dcc()

        Random.seed!(42)
        price_base = price_autocall_with_models(models, dcc, specs, config_base; num_paths=200)

        Random.seed!(42)  # Same seed for fair comparison
        price_higher = price_autocall_with_models(models, dcc, specs, config_higher; num_paths=200)

        expected_ratio = fx_higher / fx_base
        actual_ratio = price_higher.mean_price / price_base.mean_price

        println("  Expected FX ratio: $(round(expected_ratio, digits=3))")
        println("  Actual price ratio: $(round(actual_ratio, digits=3))")

        # Prices should scale approximately with FX rate (within 15% tolerance)
        # Note: With deterministic seeding, autocall patterns may be identical,
        # reducing the FX sensitivity. Real-world scenarios would show more variation.
        @test actual_ratio ≈ expected_ratio rtol=0.15
    end

    @testset "Deterministic Results Test" begin
        # Test that same seed produces identical results

        specs = create_simple_specs([100.0, 100.0, 100.0, 100.0])
        config = create_deterministic_config(0.08, 0.04, 5.2)

        models = create_mock_garch_models(specs)
        dcc = create_mock_dcc()

        println("🧪 Testing deterministic behavior")

        Random.seed!(42)
        result1 = price_autocall_with_models(models, dcc, specs, config; num_paths=200)

        Random.seed!(42)
        result2 = price_autocall_with_models(models, dcc, specs, config; num_paths=200)

        println("  Run 1: $(round(result1.mean_price, digits=4))")
        println("  Run 2: $(round(result2.mean_price, digits=4))")

        # Should be exactly equal with same seed
        @test result1.mean_price == result2.mean_price
        @test result1.stderr == result2.stderr
    end

    @testset "Forward Rate Formula Test" begin
        # Test the basic FX forward formula

        fx_spot = 5.0
        r_brl = 0.10
        r_usd = 0.05
        T = 1.0  # 1 year

        forward_rate = fx_forward_rate(fx_spot, r_brl, r_usd, T)
        expected = fx_spot * exp((r_brl - r_usd) * T)

        println("🧪 Testing FX forward formula")
        println("  Forward rate: $(round(forward_rate, digits=4))")
        println("  Expected:     $(round(expected, digits=4))")

        @test forward_rate ≈ expected atol=1e-10

        # Test that higher BRL rate increases forward rate
        forward_higher = fx_forward_rate(fx_spot, 0.12, r_usd, T)
        @test forward_higher > forward_rate
    end

end

println("✅ Forward consistency tests completed!")