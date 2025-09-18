#!/usr/bin/env julia

# Teste simples das otimizações de performance

include("src/autocall_pricer.jl")
using Dates

println("=================================================================")
println("           TESTE DE OTIMIZAÇÕES DE PERFORMANCE")
println("=================================================================")
println()

# Setup básico usando dados hardcoded para não depender de CSVs externos
symbols = ["AMD", "AMZN", "META", "TSM"]
pricing_date = Date(2024, 3, 21)

# Usar preços fixos conhecidos
specs = [
    UnderlyingSpec("AMD", 178.68, false, 0.0),
    UnderlyingSpec("AMZN", 178.15, false, 0.0),
    UnderlyingSpec("META", 505.56, false, 0.0),
    UnderlyingSpec("TSM", 136.62, true, 0.015),
]

# Criar parâmetros NSS simplificados para teste
nss_params = NSSParameters(
    0.10,    # β₀ - Long-term level
    -0.02,   # β₁ - Slope
    0.01,    # β₂ - Short-term curvature
    0.005,   # β₃ - Long-term curvature
    1.0,     # τ₁ - First exponential decay
    5.0,     # τ₂ - Second exponential decay
    pricing_date
)

# Curva USD simplificada
usd_curve = create_usd_curve(pricing_date)
fx_spot = 5.2  # Taxa fixa para teste

principal = 5000.0
dummy_coupons = fill(0.07, 10)

config_template = AutocallConfig(
    dummy_coupons, 126, 1260,
    principal, 0.10, nss_params, usd_curve, fx_spot
)

println("⏱️ COMPARAÇÃO DE PERFORMANCE:")
println("="^60)

# Teste 1: Versão original (sem otimizações)
println("🔵 TESTE 1: Método tradicional (sem pré-simulação)")
time_start = time()

# Simular a versão sem otimização fazendo chamadas repetidas
println("  • Calibrando modelos GARCH/DCC...")
models, returns_mat = fit_all_garch(specs; pricing_date=pricing_date, innovation_dist=:student)
Z = standardised_residuals(models, returns_mat)
dcc = fit_dcc(Z)

# Fazer várias simulações separadas (simulando o método antigo)
num_tests = 5
global total_paths = 0

for i in 1:num_tests
    coupons = fill(0.07 + (i-1)*0.005, 10)  # Diferentes cupons
    cfg = AutocallConfig(coupons, 126, 1260, principal, 0.10, nss_params, usd_curve, fx_spot)
    result = price_autocall_with_models(models, dcc, specs, cfg; num_paths=5_000, returns_mat=returns_mat)
    global total_paths += 5_000
    println("    Cupom $(round((0.07 + (i-1)*0.005)*100, digits=1))%: R\$ $(round(result.mean_price, digits=2))")
end

time_traditional = time() - time_start
println("  • Tempo total: $(round(time_traditional, digits=2)) segundos")
println("  • Total de simulações: $total_paths caminhos")
println()

# Teste 2: Nova versão com pré-simulação e duas fases
println("🟢 TESTE 2: Método otimizado (com pré-simulação)")
time_start = time()

# Usar a nova função otimizada
result_optimized = find_fair_coupon(specs, config_template;
                                   target_price=principal,
                                   tolerance=10.0,  # Tolerância relaxada para teste
                                   max_evaluations=8,  # Menos avaliações para teste rápido
                                   num_paths=10_000,
                                   low_paths=3_000,
                                   innovation_dist=:student)

time_optimized = time() - time_start
println("  • Tempo total: $(round(time_optimized, digits=2)) segundos")
println("  • Cupom encontrado: $(round(result_optimized.fair_coupon*100, digits=3))%")
println("  • Preço final: R\$ $(round(result_optimized.final_price, digits=2))")
println("  • Convergiu: $(result_optimized.converged ? "✅ SIM" : "❌ NÃO")")
println()

# Análise de performance
println("📊 ANÁLISE DE PERFORMANCE:")
println("="^60)
speedup = time_traditional / time_optimized
efficiency = speedup > 1 ? "MELHORIA" : "DEGRADAÇÃO"

println("  • Tempo método tradicional: $(round(time_traditional, digits=2))s")
println("  • Tempo método otimizado: $(round(time_optimized, digits=2))s")
println("  • Speedup: $(round(speedup, digits=2))x")
println("  • Resultado: $efficiency de $(round(abs(speedup-1)*100, digits=0))%")
println()

if speedup > 1.2
    println("✅ OTIMIZAÇÃO BEM-SUCEDIDA!")
    println("  • Significativa melhoria de performance detectada")
    println("  • Pré-simulação e duas fases funcionando corretamente")
elseif speedup > 0.8
    println("⚠️  PERFORMANCE SIMILAR")
    println("  • Pequena diferença, pode ser ruído do sistema")
    println("  • Para problemas maiores, diferença seria mais significativa")
else
    println("❌ POSSÍVEL PROBLEMA")
    println("  • Método otimizado mais lento que tradicional")
    println("  • Verificar implementação das otimizações")
end

println()
println("🧪 TESTE DE VALIDAÇÃO TÉCNICA:")
println("="^60)

# Testar se a pré-simulação está funcionando
println("  • Testando pré-simulação direta...")
models_test, returns_mat_test = fit_all_garch(specs; pricing_date=pricing_date, innovation_dist=:student)
Z_test = standardised_residuals(models_test, returns_mat_test)
dcc_test = fit_dcc(Z_test)

presim_data = presimulate_paths(models_test, dcc_test, specs, config_template; num_paths=1000, returns_mat=returns_mat_test)
coupons_test = fill(0.08, 10)
price_presim = calculate_price_from_presimulated(presim_data, coupons_test, principal)

# Comparar com método tradicional
cfg_test = AutocallConfig(coupons_test, 126, 1260, principal, 0.10, nss_params, usd_curve, fx_spot)
result_traditional = price_autocall_with_models(models_test, dcc_test, specs, cfg_test; num_paths=1000, returns_mat=returns_mat_test)
price_traditional = result_traditional.mean_price

price_diff = abs(price_presim - price_traditional)
price_diff_pct = price_diff / price_traditional * 100

println("    Preço pré-simulado: R\$ $(round(price_presim, digits=2))")
println("    Preço tradicional:  R\$ $(round(price_traditional, digits=2))")
println("    Diferença absoluta: R\$ $(round(price_diff, digits=2))")
println("    Diferença relativa: $(round(price_diff_pct, digits=2))%")

if price_diff_pct < 5.0
    println("  ✅ PRECISÃO ADEQUADA: Diferença < 5%")
else
    println("  ⚠️  VERIFICAR PRECISÃO: Diferença > 5%")
end

println()
println("=================================================================")
println("CONCLUSÃO:")
if speedup > 1.1 && price_diff_pct < 5.0
    println("✅ OTIMIZAÇÕES IMPLEMENTADAS COM SUCESSO!")
    println("  • Performance melhorada significativamente")
    println("  • Precisão mantida dentro de limites aceitáveis")
    println("  • Pré-simulação e amostragem bifásica funcionando")
else
    println("⚠️  OTIMIZAÇÕES NECESSITAM AJUSTE")
    if speedup <= 1.1
        println("  • Melhoria de performance insuficiente")
    end
    if price_diff_pct >= 5.0
        println("  • Precisão comprometida")
    end
end
println("=================================================================")