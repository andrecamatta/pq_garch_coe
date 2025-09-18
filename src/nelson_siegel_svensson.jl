module NelsonSiegelSvensson

using Dates
using CSV
using DataFrames

export NSSParameters, nss_rate, nss_discount_factor, create_nss_params, load_nss_from_csv

"""
    NSSParameters

Parameters for the Nelson-Siegel-Svensson yield curve model.
"""
struct NSSParameters
    β₀::Float64  # Long-term level
    β₁::Float64  # Slope
    β₂::Float64  # Short-term curvature
    β₃::Float64  # Long-term curvature
    τ₁::Float64  # First exponential decay
    τ₂::Float64  # Second exponential decay
    pricing_date::Date
end

"""
    create_nss_params(; β₀, β₁, β₂, β₃, τ₁, τ₂, pricing_date=Date(2024, 3, 21))

Create Nelson-Siegel-Svensson parameters with named arguments.
"""
function create_nss_params(;
    β₀::Float64=0.0,
    β₁::Float64=0.0,
    β₂::Float64=0.0,
    β₃::Float64=0.0,
    τ₁::Float64=1.0,
    τ₂::Float64=1.0,
    pricing_date::Date=Date(2024, 3, 21))

    return NSSParameters(β₀, β₁, β₂, β₃, τ₁, τ₂, pricing_date)
end

"""
    nss_rate(params::NSSParameters, T::Real; continuous::Bool=true)

Calculate the interest rate for maturity T (in years) using the NSS model.
Returns continuous rate by default, set continuous=false for annual compounding.
"""
function nss_rate(params::NSSParameters, T::Real; continuous::Bool=true)
    if T <= 0
        return params.β₀ + params.β₁  # Instantaneous forward rate
    end

    # NSS formula
    term1 = (1 - exp(-T/params.τ₁)) / (T/params.τ₁)
    term2 = term1 - exp(-T/params.τ₁)
    term3 = (1 - exp(-T/params.τ₂)) / (T/params.τ₂) - exp(-T/params.τ₂)

    rate = params.β₀ + params.β₁ * term1 + params.β₂ * term2 + params.β₃ * term3

    # Convert to annual compounding if requested
    if !continuous
        rate = exp(rate) - 1
    end

    return rate
end

"""
    nss_discount_factor(params::NSSParameters, T::Real)

Calculate the discount factor for maturity T (in years) using the NSS model.
"""
function nss_discount_factor(params::NSSParameters, T::Real)
    if T <= 0
        return 1.0
    end

    rate = nss_rate(params, T, continuous=true)
    return exp(-rate * T)
end

"""
    interpolate_rate_for_date(params::NSSParameters, target_date::Date)

Calculate the rate for a specific date, given the pricing date in params.
"""
function interpolate_rate_for_date(params::NSSParameters, target_date::Date)
    days_diff = Dates.value(target_date - params.pricing_date)
    years = days_diff / 365.25  # Approximate years

    if years < 0
        error("Target date cannot be before pricing date")
    end

    return nss_rate(params, years)
end

"""
    get_forward_rate(params::NSSParameters, T1::Real, T2::Real)

Calculate the forward rate between times T1 and T2 (in years).
"""
function get_forward_rate(params::NSSParameters, T1::Real, T2::Real)
    if T2 <= T1
        error("T2 must be greater than T1")
    end

    df1 = nss_discount_factor(params, T1)
    df2 = nss_discount_factor(params, T2)

    # Forward rate formula
    forward_rate = -log(df2/df1) / (T2 - T1)

    return forward_rate
end

"""
    term_structure(params::NSSParameters; max_years::Int=30, step::Float64=0.25)

Generate the full term structure of interest rates.
Returns a tuple of (maturities, rates).
"""
function term_structure(params::NSSParameters; max_years::Int=30, step::Float64=0.25)
    maturities = collect(step:step:max_years)
    rates = [nss_rate(params, T) for T in maturities]

    return maturities, rates
end

# Brazilian market specific helpers

"""
    nss_params_brazil_example()

Example NSS parameters for Brazilian market (placeholder values).
These should be replaced with actual calibrated parameters.
"""
function nss_params_brazil_example()
    # Example parameters - REPLACE WITH ACTUAL VALUES
    return create_nss_params(
        β₀ = 0.1165,  # Long-term level around 11.65%
        β₁ = -0.02,   # Negative slope (normal yield curve)
        β₂ = -0.03,   # Curvature
        β₃ = 0.01,    # Additional curvature
        τ₁ = 2.0,     # Decay parameter 1
        τ₂ = 5.0,     # Decay parameter 2
        pricing_date = Date(2024, 3, 21)
    )
end

"""
    load_nss_from_csv(csv_file::String, target_date::Date)

Load NSS parameters from CSV file for a specific date.
Expects CSV with columns: Data, Sucesso, Beta0, Beta1, Beta2, Beta3, Tau1, Tau2
"""
function load_nss_from_csv(csv_file::String, target_date::Date)
    if !isfile(csv_file)
        error("CSV file not found: $csv_file")
    end

    df = CSV.read(csv_file, DataFrame)

    # Convert Data column to Date
    df.Data = Date.(df.Data)

    # Filter for target date and successful calibrations
    filtered = df[(df.Data .== target_date) .& (df.Sucesso .== true), :]

    if nrow(filtered) == 0
        error("No successful NSS parameters found for date $target_date in $csv_file")
    end

    # Take the first (should be only) row
    row = filtered[1, :]

    return create_nss_params(
        β₀ = row.Beta0,
        β₁ = row.Beta1,
        β₂ = row.Beta2,
        β₃ = row.Beta3,
        τ₁ = row.Tau1,
        τ₂ = row.Tau2,
        pricing_date = target_date
    )
end

"""
    display_curve_info(params::NSSParameters)

Display information about the NSS curve.
"""
function display_curve_info(params::NSSParameters)
    println("Nelson-Siegel-Svensson Curve Parameters")
    println("=" ^ 50)
    println("Pricing Date: $(params.pricing_date)")
    println("β₀ (Level):     $(round(params.β₀, digits=4))")
    println("β₁ (Slope):     $(round(params.β₁, digits=4))")
    println("β₂ (Curvature): $(round(params.β₂, digits=4))")
    println("β₃ (Curvature): $(round(params.β₃, digits=4))")
    println("τ₁ (Decay 1):   $(round(params.τ₁, digits=4))")
    println("τ₂ (Decay 2):   $(round(params.τ₂, digits=4))")
    println()
    println("Sample Rates (continuous):")
    for T in [0.25, 0.5, 1, 2, 5, 10]
        rate = nss_rate(params, T) * 100
        println("  $(T) year(s): $(round(rate, digits=2))%")
    end
end

end # module