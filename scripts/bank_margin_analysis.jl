#!/usr/bin/env julia

# Comprehensive Bank Margin Analysis for COE Autocall Tech
# Analyzes bank profitability comparing offered coupon (8.8%) against fair value

include(joinpath(@__DIR__, "..", "src", "autocall_pricer.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation_export.jl"))
using Dates

println("🏦 ANÁLISE COMPLETA DE MARGEM BANCÁRIA - COE AUTOCALL TECH")
println("=" ^ 80)
println()

# Setup - Use historical pricing date to avoid API issues
pricing_date = Date(2024, 3, 21)

try
    # Get current prices from historical data
    symbols = ["AMD", "AMZN", "META", "TSM"]
    current_prices = get_current_prices(symbols; target_date=pricing_date)

    println("📊 Preços dos ativos em $(Dates.format(pricing_date, "dd/mm/yyyy")):")
    for (symbol, price) in current_prices
        println("  $symbol: \$$(round(price, digits=2))")
    end
    println()

    # Create underlying specifications
    specs = [
        UnderlyingSpec("AMD", current_prices["AMD"], false, 0.0),
        UnderlyingSpec("AMZN", current_prices["AMZN"], false, 0.0),
        UnderlyingSpec("META", current_prices["META"], false, 0.0),
        UnderlyingSpec("TSM", current_prices["TSM"], true, 0.015),  # TSM has dividend yield
    ]

    # Create Brazilian NSS curve
    csv_file = "curvas_nss_2025-08-15_17-28-38.csv"
    nss_params = load_nss_from_csv(csv_file, pricing_date)

    # Create USD Treasury curve
    usd_curve = create_usd_curve(pricing_date)

    # FX spot rate estimated from interest rate parity
    fx_spot = estimate_fx_spot_from_curves(nss_params, usd_curve)
    println("📈 Taxa de câmbio estimada: R\$ $(round(fx_spot, digits=2)) por USD")
    println()

    # COE Configuration with base coupon for comparison
    coupons_base = fill(0.07, 10)  # Base case: 7% semestral
    config_template = AutocallConfig(
        coupons_base,
        126,  # 6 months between observations (126 trading days)
        1260, # 5 years total (252 * 5 = 1260 trading days)
        5000.0,  # R$ 5,000 principal (typical COE size)
        0.10,    # 10% fallback risk-free rate
        nss_params,
        usd_curve,
        fx_spot
    )

    println("📋 Configuração do COE Autocall Tech:")
    println("  • Principal: R\$ $(round(config_template.principal, digits=2))")
    println("  • Prazo: $(config_template.horizon_days) dias ($(round(config_template.horizon_days/252, digits=1)) anos)")
    println("  • Observações: $(length(coupons_base)) semestrais")
    println("  • Taxa FX: $(round(fx_spot, digits=4)) BRL/USD")
    println()

    # ================================
    # MAIN MARGIN ANALYSIS
    # ================================
    println("🎯 ANÁLISE PRINCIPAL: CUPOM 8.8% vs CUPOM JUSTO")
    println("=" ^ 80)

    # Analyze bank margin with offered coupon (8.8% semestral)
    margin_analysis = calculate_bank_margin(
        specs, config_template;
        offered_coupon = 0.088,      # 8.8% semestral offered by bank
        operational_cost_rate = 0.005, # 0.5% per year operational costs
        risk_buffer_rate = 0.015,    # 1.5% risk buffer
        capital_ratio = 0.12,        # 12% regulatory capital
        cost_of_capital = 0.15,      # 15% cost of capital
        num_paths = 30_000,          # Higher precision for bank analysis
        scenarios = [:base, :stress, :optimistic]
    )

    # ================================
    # SENSITIVITY ANALYSIS
    # ================================
    println("\n📈 ANÁLISE DE SENSIBILIDADE DA MARGEM")
    println("=" ^ 80)

    sensitivity_results = margin_sensitivity_analysis(
        specs, config_template;
        offered_coupon = 0.088,
        vol_range = [-0.3, -0.1, 0.0, 0.2, 0.5],      # -30% to +50% volatility
        corr_range = [-0.2, -0.1, 0.0, 0.1, 0.3],     # -20% to +30% correlation
        rate_range = [-0.02, -0.01, 0.0, 0.01, 0.02]  # -200bps to +200bps rates
    )

    # ================================
    # COMPETITIVE ANALYSIS
    # ================================
    println("\n🏆 ANÁLISE COMPETITIVA - DIFERENTES CUPONS")
    println("=" ^ 80)

    competitive_coupons = [0.07, 0.075, 0.08, 0.085, 0.088, 0.09]
    competitive_results = []

    for coupon in competitive_coupons
        println("\n🔍 Analisando cupom $(round(coupon*100, digits=1))%...")

        # Quick margin analysis for each coupon
        margin = calculate_bank_margin(
            specs, config_template;
            offered_coupon = coupon,
            num_paths = 15_000,  # Faster for comparative analysis
            scenarios = [:base]  # Base scenario only
        )

        push!(competitive_results, (
            coupon = coupon,
            net_margin = margin.net_margin,
            raroc = margin.raroc,
            competitiveness = margin.market_competitiveness
        ))
    end

    # Print competitive summary
    println("\n📊 RESUMO COMPETITIVO:")
    println("=" ^ 60)
    println(rpad("Cupom", 8), rpad("Margem Líq.", 12), rpad("RAROC", 8), "Competitividade")
    println("-" ^ 60)

    for result in competitive_results
        coupon_str = "$(round(result.coupon*100, digits=1))%"
        margin_str = "R\$ $(round(result.net_margin, digits=0))"
        raroc_str = "$(round(result.raroc*100, digits=1))%"

        println(rpad(coupon_str, 8), rpad(margin_str, 12), rpad(raroc_str, 8), result.competitiveness)
    end

    # ================================
    # EXPORT RESULTS
    # ================================
    println("\n💾 EXPORTANDO RESULTADOS COMPLETOS...")
    println("=" ^ 80)

    # Create comprehensive results directory
    output_dir = create_results_directory("bank_margin_analysis")

    # Export main margin analysis
    export_bank_margin_results(margin_analysis, sensitivity_results, specs, config_template, output_dir)

    # Export competitive analysis
    competitive_df = DataFrame([
        (coupon_pct = r.coupon*100, net_margin_brl = r.net_margin,
         raroc_pct = r.raroc*100, competitiveness = r.competitiveness)
        for r in competitive_results
    ])
    competitive_file = joinpath(output_dir, "competitive_analysis.csv")
    CSV.write(competitive_file, competitive_df)
    println("🏆 Análise competitiva salva: $competitive_file")

    # ================================
    # EXECUTIVE SUMMARY
    # ================================
    println("\n💼 RESUMO EXECUTIVO PARA O BANCO")
    println("=" ^ 80)

    println("📈 RESULTADO PRINCIPAL (Cupom 8.8%):")
    println("  • Margem Bruta:       R\$ $(round(margin_analysis.margin_absolute, digits=2))")
    println("  • Margem Líquida:     R\$ $(round(margin_analysis.net_margin, digits=2))")
    println("  • RAROC:              $(round(margin_analysis.raroc*100, digits=1))%")
    println("  • Spread sobre justo: $(round(margin_analysis.gross_spread*100, digits=1)) p.p.")
    println()

    println("🎯 RECOMENDAÇÕES:")
    if margin_analysis.net_margin > 0
        println("  ✅ Produto RENTÁVEL com margem líquida positiva")
        println("  ✅ RAROC de $(round(margin_analysis.raroc*100, digits=1))% $(margin_analysis.raroc > 0.15 ? "ACIMA" : "ABAIXO") do custo de capital")
    else
        println("  ⚠️ Produto com margem NEGATIVA - requer ajuste")
    end

    println("  📊 Competitividade: $(margin_analysis.market_competitiveness)")

    # Find optimal coupon from competitive analysis
    optimal_result = competitive_results[argmax([r.raroc for r in competitive_results])]
    println("  🎯 Cupom ótimo (maior RAROC): $(round(optimal_result.coupon*100, digits=1))%")

    println("\n📁 ARQUIVOS GERADOS:")
    println("  • bank_margin_report.md - Relatório executivo completo")
    println("  • bank_margin_analysis.csv - Dados detalhados da margem")
    println("  • margin_scenarios.csv - Análise de cenários")
    println("  • margin_sensitivity.csv - Análise de sensibilidade")
    println("  • competitive_analysis.csv - Comparação de cupons")

    println("\n🏦 DIRETÓRIO: $output_dir")
    println("=" ^ 80)

catch e
    println("❌ Erro durante a análise: $e")
    println("Verifique se todos os arquivos necessários estão disponíveis.")
    println("Arquivo NSS necessário: curvas_nss_2025-08-15_17-28-38.csv")
end
