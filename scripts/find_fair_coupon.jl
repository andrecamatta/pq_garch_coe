#!/usr/bin/env julia

# Find Fair Coupon Rate for COE Autocall Tech
# Now includes bank margin analysis comparing fair vs offered coupons

include("../src/autocall_pricer.jl")
include("../src/simulation_export.jl")
using Dates

println("=================================================================")
println("         CUPOM JUSTO - COE AUTOCALL TECH")
println("=================================================================")
println()

# Get current prices
symbols = ["AMD", "AMZN", "META", "TSM"]

try
    # Use historical prices on pricing date (21/03/2024)
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
        UnderlyingSpec("TSM", current_prices["TSM"], true, 0.015),  # TSM has dividend yield
    ]

    # Create Brazilian NSS curve for payoff discounting
    csv_file = "curvas_nss_2025-08-15_17-28-38.csv"
    nss_params = load_nss_from_csv(csv_file, pricing_date)

    # Create USD Treasury curve for asset simulation only
    usd_curve = create_usd_curve(pricing_date)

    # FX spot rate BRL/USD estimated from interest rate parity
    fx_spot = estimate_fx_spot_from_curves(nss_params, usd_curve)
    println("📈 Taxa de câmbio estimada: R\$ $(round(fx_spot, digits=2)) por USD")

    println("📝 Configuração do COE:")
    println("  • Prazo: 5 anos (10 observações semestrais)")
    println("  • Principal: R\$ 5,000.00")
    println("  • Capital protegido ao vencimento")
    println("  • Data de precificação: 21/03/2024")
    println()

    # Show yield curve info
    println("📈 Curva de Juros USD Treasury (21/03/2024):")
    rate_1y = usd_rate(usd_curve, 1.0) * 100
    rate_2y = usd_rate(usd_curve, 2.0) * 100
    rate_5y = usd_rate(usd_curve, 5.0) * 100
    println("  • Taxa 1 ano:  $(round(rate_1y, digits=2))% a.a.")
    println("  • Taxa 2 anos: $(round(rate_2y, digits=2))% a.a.")
    println("  • Taxa 5 anos: $(round(rate_5y, digits=2))% a.a.")
    println("  • Fed Funds na época: ~5.25-5.50% a.a.")
    println()

    # Create template configuration (cupom will be adjusted by the solver)
    obs_spacing_days = 126
    horizon_days = 1260
    principal = 5000.0
    rf_rate = 0.10  # Fallback rate
    dummy_coupons = fill(0.07, 10)  # Will be replaced by the solver

    config_template = AutocallConfig(
        dummy_coupons, obs_spacing_days, horizon_days,
        principal, rf_rate, nss_params, usd_curve, fx_spot
    )

    # Find fair coupon using improved t-Student GARCH calibration
    result = find_fair_coupon(specs, config_template;
                             target_price=principal,
                             tolerance=5.0,  # R$ 5.00 tolerance for faster convergence
                             num_paths=10_000,
                             innovation_dist=:student)  # Use t-Student for consistency

    println()
    println("=================================================================")
    println("                        RESULTADO")
    println("=================================================================")
    println()

    if result.converged
        fair_coupon_pct = result.fair_coupon * 100
        fair_coupon_annual = ((1 + result.fair_coupon)^2 - 1) * 100

        println("💰 Cupom Justo Encontrado:")
        println("  • Taxa semestral: $(round(fair_coupon_pct, digits=3))%")
        println("  • Taxa anual equiv.: $(round(fair_coupon_annual, digits=2))%")
        println("  • Valor resultante: R\$ $(round(result.final_price, digits=2))")
        println("  • Erro: R\$ $(round(abs(result.final_price - principal), digits=2))")
        println()

        # Compare with document range
        println("📊 Comparação com o documento:")
        println("  • Range do documento: 7,00% - 8,80% a.s.")
        println("  • Cupom justo calculado: $(round(fair_coupon_pct, digits=2))% a.s.")
        println()

        if result.fair_coupon >= 0.07 && result.fair_coupon <= 0.088
            println("✅ Cupom justo está DENTRO do range do documento!")
            if result.fair_coupon <= 0.075
                println("  → Próximo ao mínimo (7,00%)")
            elseif result.fair_coupon >= 0.08
                println("  → Próximo ao máximo (8,80%)")
            else
                println("  → No meio do range")
            end
        elseif result.fair_coupon < 0.07
            println("⚠️  Cupom justo está ABAIXO do mínimo do documento (7,00%)")
            println("  → COE pode estar oferecendo valor ao investidor")
        else
            println("⚠️  Cupom justo está ACIMA do máximo do documento (8,80%)")
            println("  → COE pode estar oferecendo pouco valor ao investidor")
        end

    else
        println("❌ Não foi possível encontrar o cupom justo")
        println("  • Última tentativa: $(round(result.fair_coupon * 100, digits=2))% a.s.")
        println("  • Valor resultante: R\$ $(round(result.final_price, digits=2))")
    end

    # ================================
    # BANK MARGIN ANALYSIS
    # ================================
    if result.converged
        println()
        println("🏦 ANÁLISE DE MARGEM BANCÁRIA")
        println("=================================================================")
        println("Comparando cupom máximo oferecido (8,8%) com cupom justo calculado...")
        println()

        try
            # Calculate bank margin with maximum offered coupon
            margin_analysis = calculate_bank_margin(
                specs, config;
                offered_coupon = 0.088,      # Maximum offered: 8.8%
                operational_cost_rate = 0.005, # 0.5% per year
                risk_buffer_rate = 0.015,    # 1.5% risk buffer
                capital_ratio = 0.12,        # 12% regulatory capital
                cost_of_capital = 0.15,      # 15% cost of capital
                num_paths = 20_000,
                scenarios = [:base, :stress, :optimistic]
            )

            println()
            println("💼 RESUMO DE MARGEM (Cupom 8,8%):")
            println("  • Spread sobre justo: $(round((0.088 - result.fair_coupon)*100, digits=1)) p.p.")
            println("  • Margem bruta: R\$ $(round(margin_analysis.margin_absolute, digits=2))")
            println("  • Margem líquida: R\$ $(round(margin_analysis.net_margin, digits=2))")
            println("  • Margem %: $(round(margin_analysis.net_margin/principal*100, digits=1))% do principal")
            println("  • RAROC: $(round(margin_analysis.raroc*100, digits=1))%")
            println("  • Competitividade: $(margin_analysis.market_competitiveness)")
            println()

            if margin_analysis.net_margin > 0
                println("✅ MARGEM POSITIVA: Produto rentável para o banco")
            else
                println("⚠️ MARGEM NEGATIVA: Requer ajuste no cupom")
            end

            # Export margin analysis
            output_dir = create_results_directory("fair_coupon_margin")
            export_bank_margin_results(margin_analysis, nothing, specs, config, output_dir)
            println("📁 Análise detalhada exportada para: $output_dir")

        catch margin_error
            println("⚠️ Erro na análise de margem: $margin_error")
        end
    end

    println()
    println("=================================================================")
    println("NOTAS IMPORTANTES:")
    println("• Cálculo baseado em preços atuais dos ativos.")
    println("• Para análise na data de emissão, usar preços de 21/03/2024.")
    println("• O 'cupom justo' é calculado usando VALOR PRESENTE (PV).")
    println("• Investidores recebem VALORES NOMINAIS (maiores que PV).")
    println("• Use os scripts de análise para ver ambas as métricas.")
    println("• NOVA: Análise de margem bancária incluída!")
    println("=================================================================")

catch e
    println()
    println("❌ Erro ao executar busca do cupom justo:")
    println()
    if occursin("TIINGO_API_KEY", string(e))
        println("⚠️  API Key do Tiingo não configurada!")
        println()
        println("Por favor, configure sua chave API no arquivo .env")
    else
        println(e)
    end
    println()
end