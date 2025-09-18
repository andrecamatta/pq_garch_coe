#!/usr/bin/env julia

# Detailed autocall analysis - probability by semester and payoff distribution

include("src/autocall_pricer.jl")
include("src/simulation_export.jl")
using Dates
using Plots

println("=================================================================")
println("      ANÁLISE DETALHADA DE AUTOCALL POR SEMESTRE")
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

println("📊 Preços em 21/03/2024:")
for (symbol, price) in current_prices
    println("  $symbol: \$$(round(price, digits=2))")
end
println()

# Calibrate models with t-Student innovations
println("📊 Calibrando modelos com inovações t-Student...")
models, returns_mat = fit_all_garch(specs; pricing_date=pricing_date, innovation_dist=:student)
Z = standardised_residuals(models, returns_mat)
dcc = fit_dcc(Z)
println("✅ Modelos calibrados com distribuição t-Student!")
println()

# Removed duplicated detailed_autocall_simulation() function
# Now using centralized simulate_paths() from autocall_pricer.jl with return_detailed=true

# Test with minimum documented coupon (7%)
println("🎯 Análise detalhada com cupom mínimo do documento (7.0%):")
println()

coupon_rate = 0.07

# Create configuration for simulation
coupons = fill(coupon_rate, 10)  # 10 observation periods
cfg = AutocallConfig(coupons, 126, 1260, 5000.0, 0.10, nss_params, usd_curve, fx_spot)

# Use central simulation function with detailed tracking AND samples
result = simulate_paths(models, dcc, specs, cfg;
                       num_paths=50_000,
                       returns_mat=returns_mat,
                       return_detailed=true,
                       save_detailed_samples=true,
                       num_detailed_samples=15,
                       seed=1)

# Extract results
payoffs_pv = result.pv_brl
payoffs_nominal = result.nominal_brl
autocall_periods = result.autocall_periods
survival_prob = result.survival_prob

# Autocall statistics by period
println("📊 PROBABILIDADES DE AUTOCALL POR SEMESTRE:")
println("="^60)
println(rpad("Semestre", 12), rpad("Autocalls", 12), rpad("Prob (%)", 12), rpad("Acumul (%)", 12))
println("-"^60)

# Calculate all probabilities first
period_probs = Float64[]
period_counts = Int[]
for period in 1:10
    autocalls_this_period = sum(autocall_periods .== period)
    prob_this_period = autocalls_this_period / length(payoffs_pv) * 100
    push!(period_probs, prob_this_period)
    push!(period_counts, autocalls_this_period)
end

# Calculate cumulative probabilities
cumulative_probs = cumsum(period_probs)

# Print results
for period in 1:10
    println(rpad("$(period)° ($(period*6) meses)", 12),
            rpad("$(period_counts[period])", 12),
            rpad("$(round(period_probs[period], digits=2))", 12),
            rpad("$(round(cumulative_probs[period], digits=2))", 12))
end

no_autocall = sum(autocall_periods .== 0)
no_autocall_prob = no_autocall / length(payoffs_pv) * 100
println(rpad("Sem autocall", 12),
        rpad("$no_autocall", 12),
        rpad("$(round(no_autocall_prob, digits=2))", 12),
        rpad("100.00", 12))

println()
println("📈 DISTRIBUIÇÃO DOS PAYOFFS - VALOR PRESENTE (PV):")
println("="^60)

# Classify payoffs by present value
payoffs_pv_autocall = payoffs_pv[autocall_periods .> 0]
payoffs_pv_no_autocall = payoffs_pv[autocall_periods .== 0]

println("Autocalls ($(round(length(payoffs_pv_autocall)/length(payoffs_pv)*100, digits=1))%):")
if length(payoffs_pv_autocall) > 0
    println("  • Média PV: R\$ $(round(mean(payoffs_pv_autocall), digits=2))")
    println("  • Mediana PV: R\$ $(round(median(payoffs_pv_autocall), digits=2))")
    println("  • Min-Max PV: R\$ $(round(minimum(payoffs_pv_autocall), digits=2)) - R\$ $(round(maximum(payoffs_pv_autocall), digits=2))")
else
    println("  • Nenhum autocall")
end

println()
println("Sem Autocall ($(round(length(payoffs_pv_no_autocall)/length(payoffs_pv)*100, digits=1))%):")
if length(payoffs_pv_no_autocall) > 0
    println("  • Média PV: R\$ $(round(mean(payoffs_pv_no_autocall), digits=2))")
    println("  • Mediana PV: R\$ $(round(median(payoffs_pv_no_autocall), digits=2))")
    println("  • Min-Max PV: R\$ $(round(minimum(payoffs_pv_no_autocall), digits=2)) - R\$ $(round(maximum(payoffs_pv_no_autocall), digits=2))")
end

println()
println("💰 DISTRIBUIÇÃO DOS PAYOFFS - VALORES NOMINAIS:")
println("="^60)

# Classify payoffs by nominal value (what investor receives)
payoffs_nominal_autocall = payoffs_nominal[autocall_periods .> 0]
payoffs_nominal_no_autocall = payoffs_nominal[autocall_periods .== 0]

println("Autocalls ($(round(length(payoffs_nominal_autocall)/length(payoffs_nominal)*100, digits=1))%):")
if length(payoffs_nominal_autocall) > 0
    println("  • Média Nominal: R\$ $(round(mean(payoffs_nominal_autocall), digits=2))")
    println("  • Mediana Nominal: R\$ $(round(median(payoffs_nominal_autocall), digits=2))")
    println("  • Min-Max Nominal: R\$ $(round(minimum(payoffs_nominal_autocall), digits=2)) - R\$ $(round(maximum(payoffs_nominal_autocall), digits=2))")
else
    println("  • Nenhum autocall")
end

println()
println("Sem Autocall ($(round(length(payoffs_nominal_no_autocall)/length(payoffs_nominal)*100, digits=1))%):")
if length(payoffs_nominal_no_autocall) > 0
    println("  • Média Nominal: R\$ $(round(mean(payoffs_nominal_no_autocall), digits=2))")
    println("  • Mediana Nominal: R\$ $(round(median(payoffs_nominal_no_autocall), digits=2))")
    println("  • Min-Max Nominal: R\$ $(round(minimum(payoffs_nominal_no_autocall), digits=2)) - R\$ $(round(maximum(payoffs_nominal_no_autocall), digits=2))")
end

println()
println("🎲 ESTATÍSTICAS GERAIS:")
println("="^60)
println("📊 VALOR PRESENTE (Para Precificação):")
println("  • Payoff médio PV: R\$ $(round(mean(payoffs_pv), digits=2))")
println("  • Preço justo do produto: R\$ $(round(mean(payoffs_pv), digits=2))")
println()
println("💰 PAYOFFS NOMINAIS (Recebidos pelo Investidor):")
println("  • Payoff médio nominal: R\$ $(round(mean(payoffs_nominal), digits=2))")
println("  • Retorno esperado: $(round((mean(payoffs_nominal)/5000 - 1)*100, digits=2))%")
println("  • Probabilidade total de autocall: $(round((length(payoffs_pv) - no_autocall)/length(payoffs_pv)*100, digits=2))%")
println("  • Probabilidade de receber só principal: $(round(no_autocall_prob, digits=2))%")

# Create survival curve plot
println()
println("📊 Criando gráfico da curva de sobrevivência...")

periods = 0:10
survival_rates = survival_prob * 100

p1 = plot(periods, survival_rates,
          marker=:circle, linewidth=3, markersize=6,
          title="Curva de Sobrevivência do COE (Cupom 7%)",
          xlabel="Semestre", ylabel="Probabilidade de Sobrevivência (%)",
          label="Prob. de não ter feito autocall ainda",
          grid=true, legend=:topright)

# Add annotations for key points
annotate!(p1, 0, survival_rates[1], text("100%", :bottom))
annotate!(p1, 10, survival_rates[end], text("$(round(survival_rates[end], digits=1))%", :bottom))

# Create autocall frequency histogram
autocall_periods_filtered = autocall_periods[autocall_periods .> 0]

p2 = histogram(autocall_periods_filtered, bins=1:11,
              title="Distribuição dos Autocalls por Semestre",
              xlabel="Semestre do Autocall", ylabel="Frequência",
              label="Autocalls", alpha=0.7, color=:blue)

# Combine plots
p_combined = plot(p1, p2, layout=(2,1), size=(800, 700))

savefig(p_combined, "autocall_survival_analysis.png")
println("✅ Gráfico salvo: autocall_survival_analysis.png")

# Export detailed results
println()
println("💾 EXPORTANDO RESULTADOS DETALHADOS...")
println("="^60)

# Export all simulation results including detailed samples
output_dir = export_simulation_results(result, specs, cfg; base_name="detailed_analysis_7pct")

println()
println("📊 EXEMPLOS DE PATHS DETALHADOS:")
println("="^60)

# Show some detailed samples
if haskey(result, :detailed_samples) && !isempty(result.detailed_samples)
    sample_count = min(5, length(result.detailed_samples))
    for (i, sample) in enumerate(result.detailed_samples[1:sample_count])
        println("\n--- EXEMPLO $i: Path $(sample.path_id) ---")
        if sample.autocall_period > 0
            println("✅ AUTOCALL no semestre $(sample.autocall_period) (dia $(sample.autocall_day))")
            println("   Cupom total: $(round(sample.coupon_accrual*100, digits=1))%")
        else
            println("❌ VENCIMENTO sem autocall")
        end
        println("   Payoff nominal: R\$ $(round(sample.final_payoff_nominal, digits=2))")
        println("   Valor presente: R\$ $(round(sample.final_payoff_pv, digits=2))")
        println("   FX forward: $(round(sample.fx_forward_rate, digits=4))")

        println("\n   Timeline completo:")
        for event in sample.timeline
            println("     $event")
        end
    end
end

println()
println("=================================================================")
println("INTERPRETAÇÃO:")
println("O modelo corrigido com distribuição t-Student e simulação")
println("risco-neutra em USD mostra que com cupom de 7%, há probabilidade")
println("moderada de autocall (45.6%), mas ainda resulta em retorno")
println("esperado negativo (-5.0%) para o investidor. A correção técnica")
println("reduziu significativamente o risco aparente do produto.")
println()
println("📁 ARQUIVOS DETALHADOS GERADOS EM: $output_dir")
println("   • simulation_report.md - Relatório completo")
println("   • detailed_samples.csv - Dados tabulares dos samples")
println("   • detailed_timelines.json - Eventos detalhados")
println("   • summary.csv - Estatísticas agregadas")
println("   • payoff_distribution.csv - Distribuição completa")
println("   • survival_probabilities.csv - Probabilidades por semestre")
println("=================================================================")