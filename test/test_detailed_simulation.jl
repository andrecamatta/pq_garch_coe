#!/usr/bin/env julia

# Test script to demonstrate detailed simulation tracking and export features

include("src/autocall_pricer.jl")
include("src/simulation_export.jl")
using Dates

println("🔬 TESTE DE SIMULAÇÃO DETALHADA COM EXPORT")
println("=" ^ 80)
println()

# Setup with mock data (to avoid API calls for testing)
pricing_date = Date(2024, 3, 21)

# Create mock specs with reasonable prices
specs = [
    UnderlyingSpec("AMD", 180.0, false, 0.0),
    UnderlyingSpec("AMZN", 175.0, false, 0.0),
    UnderlyingSpec("META", 500.0, false, 0.0),
    UnderlyingSpec("TSM", 140.0, true, 0.015),
]

println("📊 Especificações dos ativos:")
for spec in specs
    div_str = spec.has_dividend_yield ? " (div: $(round(spec.dividend_yield*100,digits=1))%)" : ""
    println("  $(spec.symbol): \$$(spec.price0)$div_str")
end
println()

# Create Brazilian NSS curve (mock parameters)
nss_params = NSSParameters(
    0.10,   # β₀ - 10% long term rate
    -0.02,  # β₁
    -0.01,  # β₂
    0.01,   # β₃
    2.0,    # τ₁
    5.0,    # τ₂
    pricing_date
)

# Create USD curve (mock)
maturities = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
rates = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]  # Flat 5%
function flat_interpolator(T::Real)
    return 0.05
end
usd_curve = USDCurveParams(pricing_date, maturities, rates, flat_interpolator)

# COE configuration
coupons = fill(0.08, 10)  # 8% por semestre, 10 observações
fx_spot = 5.0

config = AutocallConfig(
    coupons,
    126,  # 6 meses entre observações
    1260, # 5 anos total
    1000.0,  # R$ 1000 principal
    0.10,    # 10% taxa livre de risco fallback
    nss_params,
    usd_curve,
    fx_spot
)

println("📋 Configuração do COE:")
println("  Principal: R\$ $(config.principal)")
println("  Prazo: $(config.horizon_days) dias ($(round(config.horizon_days/252, digits=1)) anos)")
println("  Cupom: $(round(coupons[1]*100, digits=1))% por semestre")
println("  Observações: $(length(coupons))")
println("  FX Spot: $(fx_spot) BRL/USD")
println()

# Create mock GARCH models (avoid API calls)
models = [
    GARCHUnivariate(nothing, 0.0001, 0.05, 0.90, 0.0, 0.0004, 8.0, :student),
    GARCHUnivariate(nothing, 0.0001, 0.06, 0.88, 0.0, 0.0005, 7.5, :student),
    GARCHUnivariate(nothing, 0.0001, 0.07, 0.85, 0.0, 0.0006, 6.8, :student),
    GARCHUnivariate(nothing, 0.0001, 0.04, 0.92, 0.0, 0.0003, 9.2, :student)
]

dcc = DCCParams(
    0.02,  # a
    0.95,  # b
    [1.0 0.5 0.5 0.4;   # Mock correlation matrix
     0.5 1.0 0.6 0.3;
     0.5 0.6 1.0 0.5;
     0.4 0.3 0.5 1.0]
)

println("🎯 Executando simulação com tracking detalhado...")
println("  Número de paths: 1000")
println("  Samples detalhados: 10")
println("  Semente: 42")
println()

# Run simulation with detailed tracking
result = simulate_paths(
    models, dcc, specs, config;
    num_paths = 1000,
    seed = 42,
    return_detailed = true,
    save_detailed_samples = true,
    num_detailed_samples = 10
)

println("✅ Simulação concluída!")
println()

# Print basic results
println("📊 Resultados básicos:")
println("  Preço médio: R\$ $(round(mean(result.pv_brl), digits=2))")
println("  Desvio padrão: R\$ $(round(std(result.pv_brl), digits=2))")
println("  IC 90%: [R\$ $(round(quantile(result.pv_brl, 0.05), digits=2)), R\$ $(round(quantile(result.pv_brl, 0.95), digits=2))]")
println()

# Show autocall statistics
if haskey(result, :autocall_periods)
    autocalls = result.autocall_periods
    autocall_rate = sum(autocalls .> 0) / length(autocalls) * 100
    println("📈 Estatísticas de autocall:")
    println("  Taxa de autocall: $(round(autocall_rate, digits=1))%")

    for period in 1:length(coupons)
        count = sum(autocalls .== period)
        prob = count / length(autocalls) * 100
        if count > 0
            println("  Semestre $period: $count autocalls ($(round(prob, digits=1))%)")
        end
    end

    no_autocall = sum(autocalls .== 0)
    println("  Vencimento: $no_autocall paths ($(round(no_autocall/length(autocalls)*100, digits=1))%)")
    println()
end

# Show examples of detailed samples
if haskey(result, :detailed_samples) && !isempty(result.detailed_samples)
    println("🔍 Exemplos de paths detalhados:")
    println()

    for (i, sample) in enumerate(result.detailed_samples[1:min(3, length(result.detailed_samples))])
        println("--- Path $(sample.path_id) ---")
        if sample.autocall_period > 0
            println("Resultado: AUTOCALL no semestre $(sample.autocall_period) (dia $(sample.autocall_day))")
        else
            println("Resultado: VENCIMENTO (sem autocall)")
        end
        println("Payoff nominal: R\$ $(round(sample.final_payoff_nominal, digits=2))")
        println("Valor presente: R\$ $(round(sample.final_payoff_pv, digits=2))")
        println("Timeline:")
        for event in sample.timeline
            println("  $event")
        end
        println()
    end
end

# Export all results
println("💾 Exportando resultados...")
output_dir = export_simulation_results(result, specs, config; base_name="test_detailed")

println()
println("🎉 Teste concluído com sucesso!")
println("📁 Verifique os arquivos gerados em: $output_dir")
println()
println("📖 Para análise detalhada, veja:")
println("  - simulation_report.md (relatório completo)")
println("  - detailed_samples.csv (dados tabulares)")
println("  - detailed_timelines.json (eventos detalhados)")