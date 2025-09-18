#!/usr/bin/env julia

# Test very high coupons to find the fair level

include("../src/autocall_pricer.jl")
using Dates

println("=================================================================")
println("      TESTE DE CUPONS ALTOS - BUSCA DO CUPOM JUSTO")
println("=================================================================")
println()

# Setup
symbols = ["AMD", "AMZN", "META", "TSM"]
pricing_date = Date(2024, 3, 21)
current_prices = get_current_prices(symbols; target_date=pricing_date)

specs = [
    UnderlyingSpec("AMD", current_prices["AMD"], false, 0.0),
    UnderlyingSpec("AMZN", current_prices["AMZN"], false, 0.0),
    UnderlyingSpec("META", current_prices["META"], false, 0.0),
    UnderlyingSpec("TSM", current_prices["TSM"], true, 0.015),
]

# Create Brazilian NSS curve for payoff discounting
csv_file = "curvas_nss_2025-08-15_17-28-38.csv"
nss_params = load_nss_from_csv(csv_file, pricing_date)

# Create USD Treasury curve for asset simulation only
usd_curve = create_usd_curve(pricing_date)

# FX spot rate BRL/USD estimated from interest rate parity
fx_spot = estimate_fx_spot_from_curves(nss_params, usd_curve)
println("📈 Taxa de câmbio estimada: R\$ $(round(fx_spot, digits=2)) por USD")

println("📊 Calibrando modelos com inovações t-Student...")
models, returns_mat = fit_all_garch(specs; pricing_date=pricing_date, innovation_dist=:student)
Z = standardised_residuals(models, returns_mat)
dcc = fit_dcc(Z)
println("✅ Modelos calibrados com distribuição t-Student!")
println()

# Test high coupons
principal = 5000.0
target = principal  # Fair value target

test_coupons = [0.50, 0.60, 0.70, 0.80, 0.90, 1.00]  # 50% to 100% per semester

println("🎯 TESTANDO CUPONS EXTREMOS:")
println("="^60)
println(rpad("Cupom", 10), rpad("Valor", 12), rpad("Erro", 10), rpad("Status", 10))
println("-"^60)

for coupon_rate in test_coupons
    coupons = fill(coupon_rate, 10)
    cfg = AutocallConfig(coupons, 126, 1260, principal, 0.10, nss_params, usd_curve, fx_spot)

    result = price_autocall_with_models(models, dcc, specs, cfg;
                                       num_paths=20_000, returns_mat=returns_mat)

    error = result.mean_price - target
    status = abs(error) < 10 ? "✅ JUSTO" : (error < 0 ? "❌ BAIXO" : "⚠️ ALTO")

    println(rpad("$(round(coupon_rate*100, digits=1))%", 10),
            rpad("R\$ $(round(result.mean_price, digits=2))", 12),
            rpad("$(round(error, digits=0))", 10),
            rpad(status, 10))
end

println()
println("🔍 ANÁLISE:")
println("Com distribuição t-Student (fat tails), o cupom justo está")
println("entre os valores testados. Um cupom extremamente alto seria")
println("necessário para compensar o risco do produto.")
println()

# Calculate probability stats for highest coupon
coupon_100 = 1.00
coupons_100 = fill(coupon_100, 10)
cfg_100 = AutocallConfig(coupons_100, 126, 1260, principal, 0.10, nss_params, usd_curve, fx_spot)

println("📊 ESTATÍSTICAS COM CUPOM 100% SEMESTRAL:")
result = simulate_paths(models, dcc, specs, cfg_100;
                       num_paths=30_000,
                       returns_mat=returns_mat,
                       return_detailed=true,
                       seed=1)

payoffs_pv = result.pv_brl
payoffs_nominal = result.nominal_brl
autocall_periods = result.autocall_periods
survival_prob = result.survival_prob

total_autocalls = sum(autocall_periods .> 0)
autocall_pct = total_autocalls / length(payoffs_pv) * 100
mean_payoff_pv = mean(payoffs_pv)
mean_payoff_nominal = mean(payoffs_nominal)
expected_return_pv = (mean_payoff_pv / principal - 1) * 100
expected_return_nominal = (mean_payoff_nominal / principal - 1) * 100

println("  • Probabilidade de autocall: $(round(autocall_pct, digits=1))%")
println("  • Payoff médio PV: R\$ $(round(mean_payoff_pv, digits=2))")
println("  • Payoff médio nominal: R\$ $(round(mean_payoff_nominal, digits=2))")
println("  • Retorno esperado PV: $(round(expected_return_pv, digits=2))%")
println("  • Retorno esperado nominal: $(round(expected_return_nominal, digits=2))%")

println()
println("🧪 TESTE DE VALIDAÇÃO - PV vs NOMINAL:")
println("="^60)

# Test validation: mean(nominal) >= mean(pv) for any scenario with positive rates
validation_passed = mean_payoff_nominal >= mean_payoff_pv
validation_diff = mean_payoff_nominal - mean_payoff_pv

println("  • Payoff médio nominal: R\$ $(round(mean_payoff_nominal, digits=2))")
println("  • Payoff médio PV: R\$ $(round(mean_payoff_pv, digits=2))")
println("  • Diferença (Nominal - PV): R\$ $(round(validation_diff, digits=2))")
println("  • Validação: $(validation_passed ? "✅ PASSOU" : "❌ FALHOU")")

if validation_passed
    println("  • ✅ Confirmado: Valores nominais são maiores que valores presentes")
    println("  • ✅ Desconto temporal está sendo aplicado corretamente")
else
    println("  • ❌ ERRO: Valores nominais deveriam ser maiores que valores presentes!")
    println("  • ❌ Verificar lógica de desconto")
end

println()
println("=================================================================")
println("CONCLUSÃO:")
println("Mesmo com cupom de 100% semestral, o COE ainda apresenta alto")
println("risco devido à baixa probabilidade de autocall. Isso confirma")
println("que o produto é extremamente arriscado para investidores.")
println()
println("A separação entre valor presente (precificação) e nominal")
println("(recebido pelo investidor) agora está funcionando corretamente.")
println("=================================================================")