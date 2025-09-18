#!/usr/bin/env julia

"""
COE AUTOCALL - ANÁLISE COMPLETA
===============================

Comando único para execução automática de toda a análise:
• Precificação Monte Carlo
• Análise de margem bancária
• Geração de relatórios HTML interativos
• Geração de relatórios Markdown tradicionais

Uso: julia coe_analysis.jl

Autor: Sistema COE Autocall Pricer
"""

using Dates, Printf

const PROJECT_DIR = @__DIR__

# Load core modules
include(joinpath(PROJECT_DIR, "src", "autocall_pricer.jl"))
include(joinpath(PROJECT_DIR, "src", "simulation_export.jl"))

function print_header()
    println()
    println("🏦" * "=" ^ 78 * "🏦")
    println("               COE AUTOCALL - ANÁLISE COMPLETA AUTOMATIZADA")
    println("🏦" * "=" ^ 78 * "🏦")
    println()
    println("⚡ Comando único para precificação, margem e relatórios completos")
    println("📅 Executado em: $(Dates.format(now(), "dd/mm/yyyy HH:MM:SS"))")
    println()
end

function load_asset_data()
    println("📊 ETAPA 1: Carregando dados dos ativos")
    println("=" ^ 50)

    # Use historical pricing date (avoids API issues)
    pricing_date = Date(2024, 3, 21)
    symbols = ["AMD", "AMZN", "META", "TSM"]

    try
        current_prices = get_current_prices(symbols; target_date=pricing_date)

        println("✅ Preços carregados para $(Dates.format(pricing_date, "dd/mm/yyyy")):")
        for (symbol, price) in current_prices
            println("  📈 $symbol: \$$(round(price, digits=2))")
        end

        # Create underlying specifications
        specs = [
            UnderlyingSpec("AMD", current_prices["AMD"], false, 0.0),
            UnderlyingSpec("AMZN", current_prices["AMZN"], false, 0.0),
            UnderlyingSpec("META", current_prices["META"], false, 0.0),
            UnderlyingSpec("TSM", current_prices["TSM"], true, 0.015)
        ]

        println("✅ Especificações dos ativos criadas")
        return specs, pricing_date

    catch e
        println("⚠️  Erro ao carregar preços da API, usando dados mock...")

        # Fallback to mock data
        specs = [
            UnderlyingSpec("AMD", 180.0, false, 0.0),
            UnderlyingSpec("AMZN", 175.0, false, 0.0),
            UnderlyingSpec("META", 500.0, false, 0.0),
            UnderlyingSpec("TSM", 140.0, true, 0.015)
        ]

        println("✅ Usando dados mock:")
        for spec in specs
            println("  📈 $(spec.symbol): \$$(spec.price0)")
        end

        return specs, pricing_date
    end
end

function setup_configuration(specs, pricing_date)
    println()
    println("⚙️  ETAPA 2: Configurando parâmetros do produto")
    println("=" ^ 50)

    csv_file = joinpath(PROJECT_DIR, "curvas_nss_2025-08-15_17-28-38.csv")
    nss_params = if isfile(csv_file)
        load_nss_from_csv(csv_file, pricing_date)
    else
        println("⚠️  Curva NSS não encontrada, usando parâmetros padrão.")
        NSSParameters(0.10, -0.02, -0.01, 0.01, 2.0, 5.0, pricing_date)
    end

    usd_curve = create_usd_curve(pricing_date)
    fx_spot = estimate_fx_spot_from_curves(nss_params, usd_curve)

    # COE Configuration
    config = AutocallConfig(
        fill(0.08, 10),    # 8% per semester
        126,               # Observation every 126 days
        1260,              # 5 years total
        5000.0,            # R$ 5,000 principal (conforme prospecto)
        0.10,              # 10% risk-free fallback
        nss_params,
        usd_curve,
        fx_spot            # FX spot rate BRL/USD
    )

    println("✅ Configuração do produto:")
    println("  💰 Principal: R\$ $(round(config.principal, digits=2))")
    println("  📅 Prazo: $(config.horizon_days) dias ($(round(config.horizon_days/252, digits=1)) anos)")
    println("  🎯 Cupom base: $(round(config.coupons[1]*100, digits=1))% semestral")
    println("  👀 Observações: A cada $(config.obs_spacing_days) dias")
    println("  💱 FX Spot: $(round(config.fx_spot, digits=4)) BRL/USD")

    return config
end

function run_monte_carlo_simulation(specs, config)
    println()
    println("🎲 ETAPA 3: Simulação Monte Carlo")
    println("=" ^ 50)

    try
        println("📊 Calibrando modelos GARCH/DCC...")
        models, returns_mat = fit_all_garch(specs; pricing_date=config.nss_params.pricing_date)
        Z = standardised_residuals(models, returns_mat)
        dcc = fit_dcc(Z)
        println("✅ Modelos calibrados com sucesso")

        println()
        println("🎯 Executando simulação Monte Carlo...")
        println("  • Número de paths: 10,000")
        println("  • Samples detalhados: 10")

        result = simulate_paths(
            models, dcc, specs, config;
            num_paths=10_000,
            return_detailed=true,
            save_detailed_samples=true,
            num_detailed_samples=10,
            returns_mat=returns_mat
        )

        println("✅ Simulação concluída!")
        println("  📊 Preço médio: R\$ $(round(mean(result.pv_brl), digits=2))")
        println("  📈 Desvio padrão: R\$ $(round(std(result.pv_brl), digits=2))")
        if !isempty(result.detailed_samples)
            autocall_rate = count(s -> s.autocall_period > 0, result.detailed_samples) / length(result.detailed_samples)
            println("  🎯 Taxa de autocall: $(round(autocall_rate * 100, digits=1))%")
        end

        return result, models, dcc

    catch e
        println("❌ Erro na simulação: $e")
        return nothing, nothing, nothing
    end
end

function analyze_bank_margin(specs, config, models, dcc)
    println()
    println("🏦 ETAPA 4: Análise de margem bancária")
    println("=" ^ 50)

    try
        println("🎯 Calculando margem para cupom oferecido de 8.8%...")

        margin_analysis = calculate_bank_margin(
            specs, config;
            offered_coupon=0.088,           # 8.8% semestral (máximo do produto)
            operational_cost_rate=0.005,    # 0.5% ao ano
            risk_buffer_rate=0.015,         # 1.5% buffer
            capital_ratio=0.12,             # 12% capital regulatório
            cost_of_capital=0.15,           # 15% custo de capital
            num_paths=20_000,
            capital_confidence_level=0.999,
            capital_multiplier=2.5
        )

        println("✅ Análise de margem concluída!")
        println("  💰 Margem líquida: R\$ $(round(margin_analysis.net_margin, digits=2))")
        println("  📊 RAROC: $(round(margin_analysis.raroc*100, digits=1))%")
        println("  🎯 Cupom justo: $(round(margin_analysis.fair_coupon*100, digits=1))%")
        println("  ⚖️  Competitividade: $(margin_analysis.market_competitiveness)")

        return margin_analysis

    catch e
        println("❌ Erro na análise de margem: $e")
        return nothing
    end
end

function generate_reports(result, margin_analysis, specs, config)
    println()
    println("📄 ETAPA 5: Geração de relatórios")
    println("=" ^ 50)

    output_dir = create_results_directory("coe_analysis")

    try
        # Generate simulation reports
        if !isnothing(result)
            println("📊 Gerando relatórios de simulação...")
            sim_dir = joinpath(output_dir, "simulation")
            export_simulation_results(result, specs, config;
                                     format=:both,
                                     output_dir=sim_dir)
            println("  ✅ Relatórios de simulação gerados em $sim_dir")
        end

        # Generate margin reports
        if !isnothing(margin_analysis)
            println("🏦 Gerando relatórios de margem...")
            margin_dir = joinpath(output_dir, "margin")
            export_bank_margin_results(margin_analysis, nothing, specs, config, margin_dir;
                                      format=:both)
            println("  ✅ Relatórios de margem gerados em $margin_dir")
        end

        return output_dir

    catch e
        println("⚠️  Erro na geração de relatórios: $e")
        return output_dir
    end
end

function print_summary(result, margin_analysis, output_dir, start_time)
    println()
    println("🎉 ANÁLISE CONCLUÍDA!")
    println("=" ^ 50)

    execution_time = now() - start_time
    execution_minutes = Dates.value(execution_time) / 60000

    println("⏱️  Tempo de execução: $(round(execution_minutes, digits=1)) minutos")
    println()

    if !isnothing(result)
        println("📊 RESULTADOS DA SIMULAÇÃO:")
        println("  • Preço médio: R\$ $(round(result.mean_price, digits=2))")
        println("  • IC 90%: [R\$ $(round(result.confidence_interval[1], digits=2)), R\$ $(round(result.confidence_interval[2], digits=2))]")
        if !isempty(result.detailed_samples)
            autocall_rate = count(s -> s.autocall_period > 0, result.detailed_samples) / length(result.detailed_samples)
            println("  • Taxa de autocall: $(round(autocall_rate*100, digits=1))%")
        end
        println()
    end

    if !isnothing(margin_analysis)
        println("🏦 RESULTADOS DA MARGEM:")
        println("  • Cupom oferecido: $(round(margin_analysis.offered_coupon*100, digits=1))%")
        println("  • Cupom justo: $(round(margin_analysis.fair_coupon*100, digits=1))%")
        println("  • Margem líquida: R\$ $(round(margin_analysis.net_margin, digits=2))")

        if margin_analysis.net_margin > 0
            println("  ✅ MARGEM POSITIVA - Produto rentável")
        else
            println("  ⚠️  MARGEM NEGATIVA - Revisar precificação")
        end

        if margin_analysis.raroc > 0.15
            println("  ✅ RAROC ADEQUADO ($(round(margin_analysis.raroc*100, digits=1))%)")
        else
            println("  ⚠️  RAROC BAIXO ($(round(margin_analysis.raroc*100, digits=1))%)")
        end
        println()
    end

    println("📁 ARQUIVOS GERADOS:")
    if isdir(output_dir)
        for (path, _, files) in walkdir(output_dir)
            relative = relpath(path, output_dir)
            for file in files
                entry = relative == "." ? file : joinpath(relative, file)
                if endswith(entry, ".html")
                    println("  🌐 $entry (relatório interativo)")
                elseif endswith(entry, ".md")
                    println("  📄 $entry (relatório markdown)")
                elseif endswith(entry, ".csv")
                    println("  📊 $entry (dados)")
                else
                    println("  📄 $entry")
                end
            end
        end
    end

    println()
    println("📂 Todos os arquivos salvos em: $output_dir")
    println()
    println("🌐 Para visualizar relatórios HTML, abra os arquivos .html no seu navegador")
    println("📋 Para relatórios tradicionais, veja os arquivos .md")

    println()
    println("🏆 ANÁLISE COE AUTOCALL FINALIZADA COM SUCESSO! 🏆")
    println()
end

function main()
    start_time = now()

    try
        # Header
        print_header()

        # Step 1: Load asset data
        specs, pricing_date = load_asset_data()

        # Step 2: Setup configuration
        config = setup_configuration(specs, pricing_date)

        # Step 3: Run Monte Carlo simulation
        result, models, dcc = run_monte_carlo_simulation(specs, config)

        # Step 4: Bank margin analysis
        margin_analysis = analyze_bank_margin(specs, config, models, dcc)

        # Step 5: Generate reports
        output_dir = generate_reports(result, margin_analysis, specs, config)

        # Summary
        print_summary(result, margin_analysis, output_dir, start_time)

    catch e
        println()
        println("❌ ERRO DURANTE A EXECUÇÃO:")
        println("   $e")
        println()
        println("🔧 Verifique:")
        println("   • Dependências instaladas (ver README.md)")
        println("   • Conexão com internet (para API de preços)")
        println("   • Permissões de escrita no diretório")
        println()
    end
end

# Execute main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
