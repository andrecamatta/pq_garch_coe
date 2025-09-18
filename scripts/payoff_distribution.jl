#!/usr/bin/env julia

# Analyze payoff distribution for COE Autocall Tech

include("src/autocall_pricer.jl")
using Dates
using Plots
using Statistics

println("=================================================================")
println("      ANÁLISE DE DISTRIBUIÇÃO DOS PAYOFFS - COE AUTOCALL")
println("=================================================================")
println()

# Get historical prices on pricing date (21/03/2024)
symbols = ["AMD", "AMZN", "META", "TSM"]
pricing_date = Date(2024, 3, 21)
current_prices = get_current_prices(symbols; target_date=pricing_date)

println("📊 Preços dos ativos em 21/03/2024:")
for (symbol, price) in current_prices
    println("  $symbol: \$$(round(price, digits=2))")
end
println()

# Create underlying specifications
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
println()

# Configuration
obs_spacing_days = 126
horizon_days = 1260
principal = 5000.0
rf_rate = 0.10

println("📈 Testando diferentes cupons para análise:")
println()

# Test multiple coupon rates
coupon_rates = [0.05, 0.07, 0.088]  # 5%, 7%, 8.8%
colors = [:blue, :green, :red]
labels = ["5.0%", "7.0% (Mín Doc)", "8.8% (Máx Doc)"]

plots_data = []

# Calibrate models once for all coupon tests - this is the key fix!
println("📊 Calibrando modelos GARCH/DCC uma única vez para todos os testes...")
models, returns_mat = fit_all_garch(specs; pricing_date=pricing_date, innovation_dist=:student)
Z = standardised_residuals(models, returns_mat)
dcc = fit_dcc(Z)
println("✅ Modelos calibrados!")
println()

for (i, coupon_rate) in enumerate(coupon_rates)
    println("🎯 Analisando cupom $(round(coupon_rate*100, digits=1))%...")

    # Create configuration
    coupons = fill(coupon_rate, 10)
    cfg = AutocallConfig(coupons, obs_spacing_days, horizon_days, principal, rf_rate, nss_params, usd_curve, fx_spot)

    println("  • Executando simulação Monte Carlo...")
    result = simulate_paths(models, dcc, specs, cfg;
                           num_paths = 50_000,
                           return_detailed = true,
                           seed = 1)

    # Extract results
    payoffs_pv = result.pv_brl
    payoffs_nominal = result.nominal_brl
    autocall_periods = result.autocall_periods
    survival_prob = result.survival_prob

    # Calculate statistics for both metrics
    mean_payoff_pv = mean(payoffs_pv)
    median_payoff_pv = median(payoffs_pv)
    std_payoff_pv = std(payoffs_pv)

    mean_payoff_nominal = mean(payoffs_nominal)
    median_payoff_nominal = median(payoffs_nominal)
    std_payoff_nominal = std(payoffs_nominal)

    # Count outcomes - correct classification using autocall_periods
    principal_only_count = sum(autocall_periods .== 0)  # No autocall occurred
    autocall_count = sum(autocall_periods .> 0)  # Autocall occurred

    println("  • Resultados (Valor Presente - Para Precificação):")
    println("    - Payoff médio PV: R\$ $(round(mean_payoff_pv, digits=2))")
    println("    - Payoff mediano PV: R\$ $(round(median_payoff_pv, digits=2))")
    println("    - Desvio padrão PV: R\$ $(round(std_payoff_pv, digits=2))")
    println()
    println("  • Resultados (Nominal - Recebido pelo Investidor):")
    println("    - Payoff médio nominal: R\$ $(round(mean_payoff_nominal, digits=2))")
    println("    - Retorno esperado: $(round((mean_payoff_nominal/principal - 1)*100, digits=2))%")
    println("    - Payoff mediano nominal: R\$ $(round(median_payoff_nominal, digits=2))")
    println("    - Desvio padrão nominal: R\$ $(round(std_payoff_nominal, digits=2))")
    println("    - Autocalls: $(round(autocall_count/length(payoffs_pv)*100, digits=1))%")
    println("    - Só principal: $(round(principal_only_count/length(payoffs_pv)*100, digits=1))%")
    println()

    push!(plots_data, (payoffs_pv=payoffs_pv, payoffs_nominal=payoffs_nominal, autocall_periods=autocall_periods,
                      label=labels[i], color=colors[i], mean_val_pv=mean_payoff_pv, mean_val_nominal=mean_payoff_nominal))
end

println("📊 Criando gráficos...")

# Create histogram plot for Present Value
p1 = plot(title="Distribuição dos Payoffs - Valor Presente (PV)",
          xlabel="Payoff (R\$)", ylabel="Densidade",
          size=(900, 600))

for (i, data) in enumerate(plots_data)
    histogram!(p1, data.payoffs_pv, bins=100, alpha=0.6, color=data.color,
               label="PV $(data.label)", normalize=:pdf)
    vline!(p1, [data.mean_val_pv], color=data.color, linewidth=2,
           linestyle=:dash, label="Média PV $(data.label)")
end

# Add principal line
vline!(p1, [principal], color=:black, linewidth=2, linestyle=:solid,
       label="Principal (R\$ 5,000)")

# Create histogram plot for Nominal Values
p2 = plot(title="Distribuição dos Payoffs - Valores Nominais (Recebidos)",
          xlabel="Payoff (R\$)", ylabel="Densidade",
          size=(900, 600))

for (i, data) in enumerate(plots_data)
    histogram!(p2, data.payoffs_nominal, bins=100, alpha=0.6, color=data.color,
               label="Nominal $(data.label)", normalize=:pdf)
    vline!(p2, [data.mean_val_nominal], color=data.color, linewidth=2,
           linestyle=:dash, label="Média Nominal $(data.label)")
end

# Add principal line
vline!(p2, [principal], color=:black, linewidth=2, linestyle=:solid,
       label="Principal (R\$ 5,000)")

# Create summary plot comparing PV vs Nominal
p3 = plot(title="Comparação PV vs Nominal por Cupom", ylabel="Payoff (R\$)",
          size=(800, 500), legend=:topright)

# Plot mean values for both metrics
means_pv = [data.mean_val_pv for data in plots_data]
means_nominal = [data.mean_val_nominal for data in plots_data]

plot!(p3, 1:length(plots_data), means_pv, marker=:circle, markersize=8,
      linewidth=3, color=:blue, label="Payoff Médio PV")
plot!(p3, 1:length(plots_data), means_nominal, marker=:square, markersize=8,
      linewidth=3, color=:red, label="Payoff Médio Nominal")

# Add principal line
hline!(p3, [principal], color=:black, linewidth=2, linestyle=:solid,
       label="Principal")

xticks!(p3, 1:length(plots_data), [data.label for data in plots_data])

# Create summary statistics tables
println("📋 RESUMO ESTATÍSTICO - VALOR PRESENTE (PV):")
println("="^80)
println(rpad("Cupom", 12), rpad("Média PV", 12), rpad("Mediana PV", 12), rpad("DP PV", 12),
        rpad("Min PV", 12), rpad("Max PV", 12))
println("-"^80)

for (i, data) in enumerate(plots_data)
    payoffs_pv = data.payoffs_pv
    println(rpad(labels[i], 12),
            rpad("R\$ $(round(mean(payoffs_pv), digits=2))", 12),
            rpad("R\$ $(round(median(payoffs_pv), digits=2))", 12),
            rpad("R\$ $(round(std(payoffs_pv), digits=2))", 12),
            rpad("R\$ $(round(minimum(payoffs_pv), digits=2))", 12),
            rpad("R\$ $(round(maximum(payoffs_pv), digits=2))", 12))
end

println()
println("💰 RESUMO ESTATÍSTICO - VALORES NOMINAIS (RECEBIDOS):")
println("="^90)
println(rpad("Cupom", 12), rpad("Média Nom", 12), rpad("Retorno %", 12), rpad("Mediana Nom", 12),
        rpad("DP Nom", 12), rpad("Min Nom", 12), rpad("Max Nom", 12))
println("-"^90)

for (i, data) in enumerate(plots_data)
    payoffs_nominal = data.payoffs_nominal
    return_pct = (mean(payoffs_nominal)/principal - 1) * 100
    println(rpad(labels[i], 12),
            rpad("R\$ $(round(mean(payoffs_nominal), digits=2))", 12),
            rpad("$(round(return_pct, digits=2))%", 12),
            rpad("R\$ $(round(median(payoffs_nominal), digits=2))", 12),
            rpad("R\$ $(round(std(payoffs_nominal), digits=2))", 12),
            rpad("R\$ $(round(minimum(payoffs_nominal), digits=2))", 12),
            rpad("R\$ $(round(maximum(payoffs_nominal), digits=2))", 12))
end

println()
println("📊 ANÁLISE DOS CENÁRIOS:")
println("="^50)

for (i, data) in enumerate(plots_data)
    payoffs_pv = data.payoffs_pv
    payoffs_nominal = data.payoffs_nominal
    autocall_periods = data.autocall_periods
    principal_only_pct = sum(autocall_periods .== 0) / length(payoffs_pv) * 100
    autocall_pct = sum(autocall_periods .> 0) / length(payoffs_pv) * 100

    println("$(labels[i]):")
    println("  • Autocall (ganho): $(round(autocall_pct, digits=1))%")
    println("  • Só principal: $(round(principal_only_pct, digits=1))%")
    println("  • Retorno esperado (nominal): $(round((mean(payoffs_nominal)/principal - 1)*100, digits=2))%")
    println()
end

# Save plots
println("💾 Salvando gráficos...")
savefig(p1, "payoff_distribution_pv.png")
savefig(p2, "payoff_distribution_nominal.png")
savefig(p3, "payoff_comparison_pv_vs_nominal.png")

# Combine all plots
p_combined = plot(p1, p2, p3, layout=(3,1), size=(900, 1200))
savefig(p_combined, "payoff_analysis_combined.png")

println("✅ Análise completa!")
println("📁 Gráficos salvos:")
println("  • payoff_distribution_pv.png (Distribuição dos Valores Presentes)")
println("  • payoff_distribution_nominal.png (Distribuição dos Valores Nominais)")
println("  • payoff_comparison_pv_vs_nominal.png (Comparação PV vs Nominal)")
println("  • payoff_analysis_combined.png (Todos os gráficos combinados)")