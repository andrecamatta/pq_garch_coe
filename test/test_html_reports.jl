#!/usr/bin/env julia

"""
Test HTML Reports System

Comprehensive test of the new HTML reports functionality for COE Autocall analysis.
Tests both simulation and margin reports with interactive charts and responsive design.
"""

include("src/autocall_pricer.jl")
include("src/simulation_export.jl")
using Dates

println("🌐 TESTE DO SISTEMA DE RELATÓRIOS HTML")
println("=" ^ 80)
println("Testando nova funcionalidade de relatórios interativos")
println()

# Check dependencies
println("🔍 Verificando dependências...")
try
    using PlotlyJS
    println("  ✅ PlotlyJS.jl encontrado")
catch
    println("  ❌ PlotlyJS.jl não encontrado")
    println("     Para instalar: Pkg.add(\"PlotlyJS\")")
end

try
    using JSON3
    println("  ✅ JSON3.jl encontrado")
catch
    println("  ❌ JSON3.jl não encontrado")
    println("     Para instalar: Pkg.add(\"JSON3\")")
end

println()

# Mock setup for testing
println("🔧 Configurando dados mock para teste...")
pricing_date = Date(2024, 3, 21)

# Mock asset specifications
specs = [
    UnderlyingSpec("AAPL", 150.0, false, 0.0),
    UnderlyingSpec("MSFT", 400.0, false, 0.0),
    UnderlyingSpec("GOOGL", 2800.0, false, 0.0),
    UnderlyingSpec("TSLA", 200.0, true, 0.02),
]

# Mock curves
nss_params = NSSParameters(0.10, -0.02, -0.01, 0.01, 2.0, 5.0, pricing_date)
maturities = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
rates = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]
function flat_interpolator(T::Real) return 0.05 end
usd_curve = USDCurveParams(pricing_date, maturities, rates, flat_interpolator)

# Configuration
config = AutocallConfig(
    fill(0.08, 10), 126, 1260, 10000.0, 0.10, nss_params, usd_curve, 5.2
)

println("📊 Configuração do teste:")
println("  • Principal: R\$ $(config.principal)")
println("  • Cupom: $(round(config.coupons[1]*100, digits=1))% por semestre")
println("  • Ativos: $(length(specs)) ($(join([s.symbol for s in specs], ", ")))")
println("  • Prazo: $(config.horizon_days) dias")
println()

# Create mock GARCH models
println("🎲 Criando modelos mock para simulação...")
models = [
    GARCHUnivariate(nothing, 0.0001, 0.05, 0.90, 0.0, 0.0004, 8.0, :student),
    GARCHUnivariate(nothing, 0.0001, 0.06, 0.88, 0.0, 0.0005, 7.5, :student),
    GARCHUnivariate(nothing, 0.0001, 0.07, 0.85, 0.0, 0.0006, 6.8, :student),
    GARCHUnivariate(nothing, 0.0001, 0.04, 0.92, 0.0, 0.0003, 9.2, :student)
]

dcc = DCCParams(
    0.02, 0.95,
    [1.0 0.5 0.6 0.4; 0.5 1.0 0.7 0.3; 0.6 0.7 1.0 0.5; 0.4 0.3 0.5 1.0]
)

# Test 1: HTML Simulation Report
println("📊 TESTE 1: Relatório de Simulação HTML")
println("=" ^ 50)

println("🎯 Executando simulação para relatório HTML...")
simulation_result = simulate_paths(
    models, dcc, specs, config;
    num_paths=500,  # Smaller for faster testing
    return_detailed=true,
    save_detailed_samples=true,
    num_detailed_samples=10
)

println("✅ Simulação concluída!")
println("  • Preço médio: R\$ $(round(simulation_result.mean_price, digits=2))")
println("  • Paths detalhados: $(length(simulation_result.detailed_samples))")
println()

println("🌐 Gerando relatório HTML de simulação...")
try
    # Test HTML export
    export_simulation_results(simulation_result, specs, config;
                             base_name="test_html_simulation",
                             format=:html)
    println("✅ Relatório HTML de simulação gerado com sucesso!")
catch e
    println("❌ Erro ao gerar relatório HTML de simulação:")
    println("   $e")
end
println()

# Test 2: HTML Margin Report
println("🏦 TESTE 2: Relatório de Margem HTML")
println("=" ^ 50)

println("🎯 Calculando margem bancária para relatório HTML...")

# Create mock margin analysis
fair_coupon = 0.12  # Mock fair coupon
offered_coupon = 0.088
principal = config.principal
market_price = simulation_result.mean_price
years = config.horizon_days / 252.0
operational_costs = principal * 0.005 * years
risk_buffer = principal * 0.015
capital_required = principal * 0.12
capital_cost = capital_required * 0.15
net_margin = (principal - market_price) - (operational_costs + risk_buffer + capital_cost)

# Mock margin analysis
mock_margin = BankMarginAnalysis(
    offered_coupon,
    fair_coupon,
    principal,
    market_price,
    principal,
    offered_coupon - fair_coupon,  # gross_spread
    principal - market_price,      # margin_absolute (corrected for bank perspective)
    (principal - market_price) / principal,  # margin_percentage
    0.005,  # operational_costs
    0.015,  # risk_buffer
    capital_cost,
    net_margin,
    100.0,  # margin_volatility
    0.975,  # var_confidence_level (placeholder)
    0.0,    # var_at_confidence (placeholder)
    0.0,    # expected_shortfall (placeholder)
    0.0,    # raroc (will calculate)
    fair_coupon,  # break_even_coupon
    0.12,   # competitive_benchmark
    "Competitivo",  # market_competitiveness
    Dict(:base => 0.0, :stress => 0.0)  # scenario_margins
)

# Calculate RAROC
mock_margin = BankMarginAnalysis(
    mock_margin.offered_coupon,
    mock_margin.fair_coupon,
    mock_margin.principal,
    mock_margin.coe_market_price,
    mock_margin.fair_market_price,
    mock_margin.gross_spread,
    mock_margin.margin_absolute,
    mock_margin.margin_percentage,
    mock_margin.operational_costs,
    mock_margin.risk_buffer,
    mock_margin.capital_cost,
    mock_margin.net_margin,
    mock_margin.margin_volatility,
    mock_margin.var_confidence_level,
    mock_margin.net_margin - 50.0,  # var_at_confidence
    mock_margin.net_margin - 100.0, # expected_shortfall
    mock_margin.net_margin / capital_required,  # raroc
    mock_margin.break_even_coupon,
    mock_margin.competitive_benchmark,
    mock_margin.market_competitiveness,
    mock_margin.scenario_margins
)

println("✅ Análise de margem preparada!")
println("  • Margem líquida: R\$ $(round(mock_margin.net_margin, digits=2))")
println("  • RAROC: $(round(mock_margin.raroc*100, digits=1))%")
println()

println("🌐 Gerando relatório HTML de margem...")
try
    # Create output directory for margin report
    output_dir = create_results_directory("test_html_margin")

    # Test HTML margin export
    export_bank_margin_results(mock_margin, nothing, specs, config, output_dir;
                               format=:html)
    println("✅ Relatório HTML de margem gerado com sucesso!")
    println("  • Diretório: $output_dir")
catch e
    println("❌ Erro ao gerar relatório HTML de margem:")
    println("   $e")
end
println()

# Test 3: Both formats
println("📋 TESTE 3: Ambos os Formatos (Markdown + HTML)")
println("=" ^ 50)

println("🌐 Gerando relatórios em ambos os formatos...")
try
    # Test both formats
    export_simulation_results(simulation_result, specs, config;
                             base_name="test_both_formats",
                             format=:both)
    println("✅ Relatórios de simulação em ambos os formatos gerados!")
catch e
    println("❌ Erro ao gerar relatórios em ambos os formatos:")
    println("   $e")
end
println()

# Summary
println("🎉 RESUMO DOS TESTES")
println("=" ^ 80)

# Check what files were created
println("📁 Verificando arquivos gerados:")
try
    results_dirs = [d for d in readdir("results") if startswith(d, "test_html") || startswith(d, "test_both")]
    sort!(results_dirs, by=x -> stat(joinpath("results", x)).mtime, rev=true)

    for dir in results_dirs[1:min(3, length(results_dirs))]  # Show latest 3
        println("  📂 $dir:")
        files = readdir(joinpath("results", dir))
        for file in files
            if endswith(file, ".html")
                println("    🌐 $file (HTML interativo)")
            elseif endswith(file, ".md")
                println("    📄 $file (Markdown)")
            elseif endswith(file, ".csv")
                println("    📊 $file (dados)")
            else
                println("    📄 $file")
            end
        end
        println()
    end
catch e
    println("  ⚠️  Erro ao listar arquivos: $e")
end

println("🔧 INSTRUÇÕES DE USO:")
println("=" ^ 30)
println("1. Para usar relatórios HTML em seus scripts:")
println("   export_simulation_results(result, specs, config; format=:html)")
println("   export_bank_margin_results(margin, nothing, specs, config, dir; format=:html)")
println()
println("2. Formatos disponíveis:")
println("   • :markdown  - Relatórios tradicionais em Markdown")
println("   • :html      - Relatórios interativos com gráficos")
println("   • :both      - Ambos os formatos")
println()
println("3. Dependências necessárias:")
println("   • PlotlyJS.jl - Para gráficos interativos")
println("   • JSON3.jl    - Para serialização de dados")
println()
println("📊 Os relatórios HTML incluem:")
println("   • Gráficos interativos (hover, zoom, pan)")
println("   • Dashboard responsivo")
println("   • Métricas visuais com cores")
println("   • Tabelas sortáveis")
println("   • Design profissional")
println()

if any(endswith(f, ".html") for d in readdir("results") if isdir(joinpath("results", d)) for f in readdir(joinpath("results", d)) if startswith(d, "test_"))
    println("✅ TESTE CONCLUÍDO COM SUCESSO!")
    println("🌐 Abra os arquivos .html em seu navegador para visualizar os relatórios interativos!")
else
    println("⚠️  Alguns testes podem ter falhado. Verifique as dependências.")
end
