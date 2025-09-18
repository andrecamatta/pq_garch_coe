# USD Treasury Curve Module
# Implements risk-free rate curve for USD-denominated assets

using Dates
using Interpolations
using CSV
using DataFrames

"""
    USDCurveParams

Structure to hold USD Treasury curve parameters and interpolation functions.
"""
struct USDCurveParams
    pricing_date::Date
    maturities::Vector{Float64}  # in years
    rates::Vector{Float64}       # continuous rates
    interpolator::Any            # interpolation function
end

"""
    load_usd_curve(pricing_date::Date)

Load USD Treasury curve for the given pricing date.
For now, uses hardcoded rates for 21/03/2024 (same date as NSS).
In production, this would load from Treasury.gov API or CSV files.

Returns USDCurveParams structure with interpolated rates.
"""
function load_usd_curve(pricing_date::Date=Date(2024, 3, 21))
    # Hardcoded Treasury rates for 21/03/2024
    # Source: approximated from Fed data around that period
    # In production: load from https://home.treasury.gov/resource-center/data-chart-center/

    if pricing_date == Date(2024, 3, 21)
        # Maturities in years, rates in decimal (already continuous approximation)
        maturities = [
            0.25,    # 3 months
            0.5,     # 6 months
            1.0,     # 1 year
            2.0,     # 2 years
            3.0,     # 3 years
            5.0,     # 5 years
            7.0,     # 7 years
            10.0,    # 10 years
            20.0,    # 20 years
            30.0     # 30 years
        ]

        # Approximate Treasury rates for March 21, 2024 (converted to continuous)
        # Fed funds rate was around 5.25-5.50% at the time
        rates = [
            0.0525,  # 3M: ~5.25%
            0.0535,  # 6M: ~5.35%
            0.0510,  # 1Y: ~5.10%
            0.0465,  # 2Y: ~4.65%
            0.0435,  # 3Y: ~4.35%
            0.0420,  # 5Y: ~4.20%
            0.0425,  # 7Y: ~4.25%
            0.0435,  # 10Y: ~4.35%
            0.0455,  # 20Y: ~4.55%
            0.0445   # 30Y: ~4.45%
        ]
    else
        # Fallback: flat curve at 4.5% for other dates
        @warn "Using flat 4.5% USD curve for date $pricing_date (only 2024-03-21 has real data)"
        maturities = [0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 7.0, 10.0, 20.0, 30.0]
        rates = fill(0.045, length(maturities))
    end

    # Create linear interpolation
    interpolator = LinearInterpolation(maturities, rates, extrapolation_bc=Line())

    return USDCurveParams(pricing_date, maturities, rates, interpolator)
end

"""
    usd_rate(curve::USDCurveParams, T::Real)

Get USD risk-free rate for maturity T (in years).
Returns continuous rate.
"""
function usd_rate(curve::USDCurveParams, T::Real)
    if T <= 0
        return curve.rates[1]  # Use shortest rate for T ≤ 0
    end
    return curve.interpolator(T)
end

"""
    usd_discount_factor(curve::USDCurveParams, T::Real)

Calculate discount factor for maturity T (in years) using USD curve.
"""
function usd_discount_factor(curve::USDCurveParams, T::Real)
    r = usd_rate(curve, T)
    return exp(-r * T)
end

"""
    create_usd_curve(pricing_date::Date=Date(2024, 3, 21))

Convenience function to create USD curve parameters.
"""
function create_usd_curve(pricing_date::Date=Date(2024, 3, 21))
    return load_usd_curve(pricing_date)
end

# Export main functions
export USDCurveParams, load_usd_curve, usd_rate, usd_discount_factor, create_usd_curve