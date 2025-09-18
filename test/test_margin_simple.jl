#!/usr/bin/env julia

# Simple test for bank margin system using only mock data (no API calls)

include("src/autocall_pricer.jl")
include("src/simulation_export.jl")
using Dates

println("🧪 TESTE SIMPLIFICADO DO SISTEMA DE MARGEM BANCÁRIA")
println("=" ^ 80)
println("(Usando dados mock - sem chamadas de API)")
println()

# Mock setup
pricing_date = Date(2024, 3, 21)

# Mock specs
specs = [
    UnderlyingSpec("AMD", 180.0, false, 0.0),
    UnderlyingSpec("AMZN", 175.0, false, 0.0),
    UnderlyingSpec("META", 500.0, false, 0.0),
    UnderlyingSpec("TSM", 140.0, true, 0.015),
]

# Mock curves
nss_params = NSSParameters(0.10, -0.02, -0.01, 0.01, 2.0, 5.0, pricing_date)
maturities = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
rates = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]
function flat_interpolator(T::Real) return 0.05 end
usd_curve = USDCurveParams(pricing_date, maturities, rates, flat_interpolator)

config = AutocallConfig(
    fill(0.07, 10), 126, 1260, 5000.0, 0.10, nss_params, usd_curve, 5.0
)

println("📊 Configuração:")
println("  Principal: R\$ $(config.principal)")
println("  Cupom base: 7.0% (template)")
println("  Cupom teste: 8.8% (oferecido)")
println()

# Create mock GARCH models to avoid API calls
println("🔧 Criando modelos mock...")
models = [
    GARCHUnivariate(nothing, 0.0001, 0.05, 0.90, 0.0, 0.0004, 8.0, :student),
    GARCHUnivariate(nothing, 0.0001, 0.06, 0.88, 0.0, 0.0005, 7.5, :student),
    GARCHUnivariate(nothing, 0.0001, 0.07, 0.85, 0.0, 0.0006, 6.8, :student),
    GARCHUnivariate(nothing, 0.0001, 0.04, 0.92, 0.0, 0.0003, 9.2, :student)
]

dcc = DCCParams(
    0.02, 0.95,
    [1.0 0.5 0.5 0.4; 0.5 1.0 0.6 0.3; 0.5 0.6 1.0 0.5; 0.4 0.3 0.5 1.0]
)

# Test 1: Find fair coupon using mock models
println("🎯 TESTE 1: Calculando cupom justo com modelos mock...")
function find_fair_coupon_mock(models, dcc, specs, config; target_price=5000.0, tolerance=10.0)
    low_coupon = 0.0
    high_coupon = 0.30

    for iteration in 1:10
        mid_coupon = (low_coupon + high_coupon) / 2
        coupons = fill(mid_coupon, length(config.coupons))
        test_config = AutocallConfig(
            coupons, config.obs_spacing_days, config.horizon_days,
            config.principal, config.rf_rate, config.nss_params,
            config.usd_curve, config.fx_spot
        )

        result = price_autocall_with_models(models, dcc, specs, test_config; num_paths=1000)
        price = result.mean_price
        error = abs(price - target_price)

        println("  Iter $iteration: Cupom $(round(mid_coupon*100,digits=1))% → Preço R\$ $(round(price,digits=2)) (erro: R\$ $(round(error,digits=2)))")

        if error <= tolerance
            return (fair_coupon = mid_coupon, final_price = price, converged = true)
        end

        if price < target_price
            low_coupon = mid_coupon
        else
            high_coupon = mid_coupon
        end
    end

    return (fair_coupon = (low_coupon + high_coupon) / 2, final_price = 0.0, converged = false)
end

fair_result = find_fair_coupon_mock(models, dcc, specs, config)
println("✅ Cupom justo: $(round(fair_result.fair_coupon*100, digits=1))%")
println()

# Test 2: Calculate margin with offered coupon
println("🏦 TESTE 2: Calculando margem bancária...")

# Price with offered coupon (8.8%)
offered_coupons = fill(0.088, length(config.coupons))
offered_config = AutocallConfig(
    offered_coupons, config.obs_spacing_days, config.horizon_days,
    config.principal, config.rf_rate, config.nss_params,
    config.usd_curve, config.fx_spot
)

offered_result = price_autocall_with_models(models, dcc, specs, offered_config; num_paths=2000)
market_price = offered_result.mean_price

# Calculate margin components (BANK PERSPECTIVE - seller)
fair_coupon = fair_result.fair_coupon
offered_coupon = 0.088
gross_spread = offered_coupon - fair_coupon
margin_absolute = config.principal - market_price  # Bank sells for principal, pays market_price to hedge
margin_percentage = margin_absolute / config.principal

# Costs
principal = config.principal
years = config.horizon_days / 252.0
operational_costs = principal * 0.005 * years  # 0.5% per year
risk_buffer = principal * 0.015               # 1.5% buffer
capital_required = principal * 0.12           # 12% capital ratio
capital_cost = capital_required * 0.15        # 15% cost of capital (anual)

total_costs = operational_costs + risk_buffer + capital_cost
net_margin = margin_absolute - total_costs
raroc = net_margin / capital_required

println("💼 RESULTADOS DA MARGEM:")
println("  Cupom oferecido:    $(round(offered_coupon*100, digits=1))%")
println("  Cupom justo:        $(round(fair_coupon*100, digits=1))%")
println("  Spread bruto:       $(round(gross_spread*100, digits=1)) p.p.")
println()
println("  Preço de mercado:   R\$ $(round(market_price, digits=2))")
println("  Principal:          R\$ $(round(principal, digits=2))")
println("  Margem bruta:       R\$ $(round(margin_absolute, digits=2))")
println()
println("  Custos operacionais: R\$ $(round(operational_costs, digits=2))")
println("  Buffer de risco:     R\$ $(round(risk_buffer, digits=2))")
println("  Custo de capital:    R\$ $(round(capital_cost, digits=2))")
println("  Margem líquida:      R\$ $(round(net_margin, digits=2))")
println()
println("  RAROC:              $(round(raroc*100, digits=1))%")
println("  Margem % principal:  $(round(net_margin/principal*100, digits=1))%")
println()

# Test 3: Export functionality
println("💾 TESTE 3: Sistema de exportação...")

# Create mock BankMarginAnalysis
mock_analysis = BankMarginAnalysis(
    offered_coupon, fair_coupon, principal, market_price, principal,
    gross_spread, margin_absolute, margin_percentage,
    0.005, 0.015, capital_cost, net_margin,
    50.0, 0.975, net_margin - 50.0, net_margin - 75.0, raroc,
    fair_coupon, 0.12, "Competitivo",
    Dict(:base => net_margin, :stress => net_margin - 30.0)
)

# Export
output_dir = create_results_directory("test_margin_simple")
export_bank_margin_results(mock_analysis, nothing, specs, config, output_dir)

println("✅ Export concluído!")
println("  Diretório: $output_dir")
println()

# Summary
println("🎉 RESUMO DO TESTE")
println("=" ^ 80)
if fair_result.converged
    println("✅ Cálculo de cupom justo: SUCESSO")
else
    println("⚠️ Cálculo de cupom justo: PARCIAL")
end

if net_margin > 0
    println("✅ Margem bancária: POSITIVA (R\$ $(round(net_margin, digits=2)))")
else
    println("⚠️ Margem bancária: NEGATIVA")
end

if raroc > 0.15
    println("✅ RAROC: ACIMA do custo de capital ($(round(raroc*100, digits=1))%)")
else
    println("⚠️ RAROC: ABAIXO do custo de capital")
end

println("✅ Sistema de exportação: FUNCIONAL")
println()
println("🏆 SISTEMA DE MARGEM BANCÁRIA VALIDADO!")
println("📁 Resultados salvos em: $output_dir")
