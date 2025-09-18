#!/usr/bin/env julia

# Simulation export utilities for COE Autocall Pricer
# Functions to save simulation results, detailed samples, and generate reports

using CSV
using DataFrames
using Dates
using JSON3
using Statistics

"""
    create_results_directory(base_name::String="simulation")

Create a timestamped directory for simulation results.
Returns the path to the created directory.
"""
function create_results_directory(base_name::String="simulation")
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    dir_name = "results/$(base_name)_$(timestamp)"
    mkpath(dir_name)
    println("📁 Diretório criado: $dir_name")
    return dir_name
end

"""
    save_simulation_summary(result, config::AutocallConfig, output_dir::String)

Save aggregated simulation results to CSV.
"""
function save_simulation_summary(result, config::AutocallConfig, output_dir::String)
    # Basic statistics
    payoffs = result.pv_brl
    nominal = result.nominal_brl

    summary_data = DataFrame(
        metric = [
            "mean_price_brl", "std_price_brl", "min_price_brl", "max_price_brl",
            "q05_price_brl", "q25_price_brl", "q50_price_brl", "q75_price_brl", "q95_price_brl",
            "mean_nominal_brl", "std_nominal_brl", "min_nominal_brl", "max_nominal_brl",
            "num_paths", "principal_brl", "fx_spot", "horizon_days", "obs_spacing_days"
        ],
        value = [
            mean(payoffs), std(payoffs), minimum(payoffs), maximum(payoffs),
            quantile(payoffs, 0.05), quantile(payoffs, 0.25), quantile(payoffs, 0.5),
            quantile(payoffs, 0.75), quantile(payoffs, 0.95),
            mean(nominal), std(nominal), minimum(nominal), maximum(nominal),
            length(payoffs), config.principal, config.fx_spot,
            config.horizon_days, config.obs_spacing_days
        ]
    )

    summary_file = joinpath(output_dir, "summary.csv")
    CSV.write(summary_file, summary_data)
    println("📊 Resumo salvo: $summary_file")
    return summary_file
end

"""
    save_payoff_distribution(result, output_dir::String)

Save complete payoff distribution to CSV.
"""
function save_payoff_distribution(result, output_dir::String)
    payoffs_df = DataFrame(
        path_id = 1:length(result.pv_brl),
        payoff_pv_brl = result.pv_brl,
        payoff_nominal_brl = result.nominal_brl
    )

    # Add autocall information if available
    if haskey(result, :autocall_periods)
        payoffs_df.autocall_period = result.autocall_periods
        payoffs_df.autocalled = result.autocall_periods .> 0
    end

    dist_file = joinpath(output_dir, "payoff_distribution.csv")
    CSV.write(dist_file, payoffs_df)
    println("📈 Distribuição de payoffs salva: $dist_file")
    return dist_file
end

"""
    save_survival_probabilities(result, config::AutocallConfig, output_dir::String)

Save survival probabilities by period to CSV.
"""
function save_survival_probabilities(result, config::AutocallConfig, output_dir::String)
    if !haskey(result, :autocall_periods)
        println("⚠️  Survival probabilities não disponíveis (return_detailed=false)")
        return nothing
    end

    autocall_periods = result.autocall_periods
    num_obs = length(config.coupons)

    # Calculate probabilities for each period
    survival_data = []
    for period in 1:num_obs
        autocalls_this_period = sum(autocall_periods .== period)
        prob_autocall = autocalls_this_period / length(autocall_periods)
        survived_to_this = sum(autocall_periods .== 0) + sum(autocall_periods .>= period)
        prob_survival = survived_to_this / length(autocall_periods)

        push!(survival_data, (
            period = period,
            semester = period,
            days = period * config.obs_spacing_days,
            autocalls_count = autocalls_this_period,
            autocall_probability = prob_autocall,
            survival_probability = prob_survival,
            cumulative_autocall_prob = sum([sum(autocall_periods .== p) for p in 1:period]) / length(autocall_periods)
        ))
    end

    # Add final row for no autocall
    no_autocall = sum(autocall_periods .== 0)
    push!(survival_data, (
        period = 0,
        semester = 0,
        days = config.horizon_days,
        autocalls_count = no_autocall,
        autocall_probability = no_autocall / length(autocall_periods),
        survival_probability = 0.0,
        cumulative_autocall_prob = 1.0
    ))

    survival_df = DataFrame(survival_data)
    survival_file = joinpath(output_dir, "survival_probabilities.csv")
    CSV.write(survival_file, survival_df)
    println("📊 Probabilidades de sobrevivência salvas: $survival_file")
    return survival_file
end

"""
    save_detailed_samples(result, specs::Vector{UnderlyingSpec}, output_dir::String)

Save detailed information about individual simulation paths.
"""
function save_detailed_samples(result, specs::Vector{UnderlyingSpec}, output_dir::String)
    if !haskey(result, :detailed_samples) || isempty(result.detailed_samples)
        println("⚠️  Samples detalhados não disponíveis (save_detailed_samples=false)")
        return nothing
    end

    samples = result.detailed_samples
    symbols = [spec.symbol for spec in specs]

    # Create detailed CSV with one row per sample
    detailed_data = []
    for sample in samples
        row = Dict(
            "path_id" => sample.path_id,
            "seed_used" => sample.seed_used,
            "autocall_period" => sample.autocall_period,
            "autocall_day" => sample.autocall_day,
            "final_payoff_nominal" => sample.final_payoff_nominal,
            "final_payoff_pv" => sample.final_payoff_pv,
            "fx_forward_rate" => sample.fx_forward_rate,
            "discount_factor_usd" => sample.discount_factor_usd,
            "coupon_accrual" => sample.coupon_accrual
        )

        # Add initial prices
        for (i, symbol) in enumerate(symbols)
            row["initial_$(symbol)"] = sample.initial_prices[i]
        end

        # Add final prices (if autocall occurred, use autocall prices; otherwise use last observation)
        if sample.autocall_period > 0
            for (i, symbol) in enumerate(symbols)
                row["final_$(symbol)"] = sample.prices_at_obs[sample.autocall_period, i]
            end
        else
            # Use last observation prices
            for (i, symbol) in enumerate(symbols)
                last_obs = size(sample.prices_at_obs, 1)
                row["final_$(symbol)"] = sample.prices_at_obs[last_obs, i]
            end
        end

        push!(detailed_data, row)
    end

    detailed_df = DataFrame(detailed_data)
    detailed_file = joinpath(output_dir, "detailed_samples.csv")
    CSV.write(detailed_file, detailed_df)
    println("🔍 Samples detalhados salvos: $detailed_file")

    # Also save timeline information as JSON for richer detail
    timeline_data = [
        Dict(
            "path_id" => sample.path_id,
            "autocall_period" => sample.autocall_period,
            "timeline" => sample.timeline,
            "obs_dates" => sample.obs_dates,
            "prices_at_obs" => [sample.prices_at_obs[i,:] for i in 1:size(sample.prices_at_obs,1)],
            "coupon_payments" => sample.coupon_payments
        )
        for sample in samples
    ]

    timeline_file = joinpath(output_dir, "detailed_timelines.json")
    open(timeline_file, "w") do io
        JSON3.pretty(io, timeline_data, allow_inf=true)
    end
    println("📋 Timelines detalhados salvos: $timeline_file")

    return (detailed_file, timeline_file)
end

"""
    generate_simulation_report(result, specs::Vector{UnderlyingSpec}, config::AutocallConfig, output_dir::String)

Generate a comprehensive markdown report of the simulation results.
"""
function generate_simulation_report(result, specs::Vector{UnderlyingSpec}, config::AutocallConfig, output_dir::String)
    report_file = joinpath(output_dir, "simulation_report.md")

    open(report_file, "w") do io
        write(io, "# Relatório de Simulação COE Autocall\n\n")
        write(io, "**Data de execução:** $(Dates.format(now(), "dd/mm/yyyy HH:MM:SS"))\n\n")

        # Configuration section
        write(io, "## Configuração da Simulação\n\n")
        write(io, "| Parâmetro | Valor |\n")
        write(io, "|-----------|-------|\n")
        write(io, "| Principal | R\$ $(round(config.principal, digits=2)) |\n")
        write(io, "| Prazo total | $(config.horizon_days) dias ($(round(config.horizon_days/252, digits=1)) anos) |\n")
        write(io, "| Observações | A cada $(config.obs_spacing_days) dias ($(length(config.coupons)) observações) |\n")
        write(io, "| Cupom por observação | $(round(config.coupons[1]*100, digits=1))% |\n")
        write(io, "| Taxa FX spot | $(round(config.fx_spot, digits=4)) BRL/USD |\n")
        write(io, "| Número de simulações | $(length(result.pv_brl)) |\n\n")

        # Underlying assets
        write(io, "### Ativos Subjacentes\n\n")
        write(io, "| Símbolo | Preço Inicial (USD) | Dividend Yield |\n")
        write(io, "|---------|---------------------|----------------|\n")
        for spec in specs
            div_str = spec.has_dividend_yield ? "$(round(spec.dividend_yield*100, digits=1))%" : "N/A"
            write(io, "| $(spec.symbol) | \$$(round(spec.price0, digits=2)) | $div_str |\n")
        end
        write(io, "\n")

        # Results summary
        write(io, "## Resultados da Simulação\n\n")
        payoffs = result.pv_brl
        nominal = result.nominal_brl

        write(io, "### Estatísticas dos Payoffs (Valor Presente)\n\n")
        write(io, "| Estatística | Valor (BRL) |\n")
        write(io, "|-------------|-------------|\n")
        write(io, "| Preço médio | R\$ $(round(mean(payoffs), digits=2)) |\n")
        write(io, "| Desvio padrão | R\$ $(round(std(payoffs), digits=2)) |\n")
        write(io, "| Mínimo | R\$ $(round(minimum(payoffs), digits=2)) |\n")
        write(io, "| Máximo | R\$ $(round(maximum(payoffs), digits=2)) |\n")
        write(io, "| 5º percentil | R\$ $(round(quantile(payoffs, 0.05), digits=2)) |\n")
        write(io, "| 25º percentil | R\$ $(round(quantile(payoffs, 0.25), digits=2)) |\n")
        write(io, "| Mediana | R\$ $(round(quantile(payoffs, 0.5), digits=2)) |\n")
        write(io, "| 75º percentil | R\$ $(round(quantile(payoffs, 0.75), digits=2)) |\n")
        write(io, "| 95º percentil | R\$ $(round(quantile(payoffs, 0.95), digits=2)) |\n\n")

        # Autocall probabilities if available
        if haskey(result, :autocall_periods)
            write(io, "### Probabilidades de Autocall por Semestre\n\n")
            write(io, "| Semestre | Observações | Prob. Autocall | Prob. Acumulada |\n")
            write(io, "|----------|-------------|----------------|------------------|\n")

            autocall_periods = result.autocall_periods
            cumulative_prob = 0.0

            for period in 1:length(config.coupons)
                count = sum(autocall_periods .== period)
                prob = count / length(autocall_periods) * 100
                cumulative_prob += prob

                write(io, "| $period | $count | $(round(prob, digits=1))% | $(round(cumulative_prob, digits=1))% |\n")
            end

            no_autocall = sum(autocall_periods .== 0)
            no_autocall_prob = no_autocall / length(autocall_periods) * 100
            write(io, "| Vencimento | $no_autocall | $(round(no_autocall_prob, digits=1))% | 100.0% |\n\n")
        end

        # Detailed samples section
        if haskey(result, :detailed_samples) && !isempty(result.detailed_samples)
            write(io, "## Exemplos Detalhados (Primeiros $(length(result.detailed_samples)) Paths)\n\n")

            for (i, sample) in enumerate(result.detailed_samples)
                write(io, "### Path $(sample.path_id) (Seed: $(sample.seed_used))\n\n")

                if sample.autocall_period > 0
                    write(io, "**Resultado:** Autocall no $(sample.autocall_period)º semestre (dia $(sample.autocall_day))\n\n")
                else
                    write(io, "**Resultado:** Vencimento sem autocall\n\n")
                end

                write(io, "**Timeline:**\n")
                for event in sample.timeline
                    write(io, "- $event\n")
                end
                write(io, "\n")

                # Price table for this sample
                write(io, "**Evolução dos Preços:**\n\n")
                write(io, "| Observação | Dias |")
                for spec in specs
                    write(io, " $(spec.symbol) |")
                end
                write(io, " Autocall? |\n")

                write(io, "|------------|------|")
                for _ in specs
                    write(io, "--------|")
                end
                write(io, "-----------|\n")

                write(io, "| Inicial | 0 |")
                for price in sample.initial_prices
                    write(io, " \$$(round(price, digits=2)) |")
                end
                write(io, " - |\n")

                for obs in 1:size(sample.prices_at_obs, 1)
                    if sample.obs_dates[obs] <= sample.autocall_day || sample.autocall_day == 0
                        day = sample.obs_dates[obs]
                        write(io, "| Semestre $obs | $day |")
                        for j in 1:size(sample.prices_at_obs, 2)
                            write(io, " \$$(round(sample.prices_at_obs[obs, j], digits=2)) |")
                        end

                        if obs == sample.autocall_period
                            write(io, " ✅ SIM |\n")
                            break
                        else
                            write(io, " ❌ Não |\n")
                        end
                    end
                end
                write(io, "\n")
            end
        end

        write(io, "---\n\n")
        write(io, "*Relatório gerado automaticamente pelo COE Autocall Pricer*\n")
    end

    println("📝 Relatório completo gerado: $report_file")
    return report_file
end

"""
    export_simulation_results(result, specs::Vector{UnderlyingSpec}, config::AutocallConfig;
                             base_name::String="simulation", format::Symbol=:markdown)

Master function to export all simulation results with detailed samples and reports.
Format options: :markdown (default), :html, :both
Returns the path to the created directory.
"""
function export_simulation_results(result, specs::Vector{UnderlyingSpec}, config::AutocallConfig;
                                  base_name::String="simulation", format::Symbol=:markdown,
                                  output_dir::Union{Nothing, String}=nothing)

    println("💾 Iniciando exportação dos resultados da simulação...")
    println("  • Formato: $format")

    # Create or reuse output directory
    output_dir = isnothing(output_dir) ? create_results_directory(base_name) : output_dir
    mkpath(output_dir)

    # Save all components (always CSV data)
    save_simulation_summary(result, config, output_dir)
    save_payoff_distribution(result, output_dir)
    save_survival_probabilities(result, config, output_dir)
    save_detailed_samples(result, specs, output_dir)

    # Generate reports based on format
    if format == :markdown || format == :both
        generate_simulation_report(result, specs, config, output_dir)
    end

    if format == :html || format == :both
        # Load HTML report module dynamically
        try
            include(joinpath(@__DIR__, "simulation_html_reports.jl"))
            Base.invokelatest(generate_html_simulation_report, result, specs, config, output_dir)
        catch e
            println("⚠️  Erro ao gerar relatório HTML: $e")
            println("   Verifique se as dependências estão instaladas: PlotlyJS, JSON3")
        end
    end

    println("✅ Exportação concluída! Todos os arquivos salvos em: $output_dir")
    println()
    println("📋 Arquivos gerados:")
    for file in readdir(output_dir)
        println("   - $file")
    end

    return output_dir
end

"""
    save_bank_margin_analysis(margin_analysis::BankMarginAnalysis, output_dir::String)

Save bank margin analysis results to CSV and detailed breakdown.
"""
function save_bank_margin_analysis(margin_analysis::BankMarginAnalysis, output_dir::String)
    mkpath(output_dir)

    # Main margin summary
    margin_summary = DataFrame(
        metric = [
            "offered_coupon_pct", "fair_coupon_pct", "gross_spread_pp",
            "principal_brl", "coe_market_price_brl", "margin_absolute_brl", "margin_percentage",
            "operational_costs_pct", "risk_buffer_pct", "capital_cost_brl", "net_margin_brl",
            "margin_volatility", "var_confidence_level_pct", "var_at_confidence_brl", "expected_shortfall_brl", "raroc_pct",
            "break_even_coupon_pct", "competitive_benchmark_pct", "market_competitiveness"
        ],
        value = [
            margin_analysis.offered_coupon * 100,
            margin_analysis.fair_coupon * 100,
            margin_analysis.gross_spread * 100,
            margin_analysis.principal,
            margin_analysis.coe_market_price,
            margin_analysis.margin_absolute,
            margin_analysis.margin_percentage * 100,
            margin_analysis.operational_costs * 100,
            margin_analysis.risk_buffer * 100,
            margin_analysis.capital_cost,
            margin_analysis.net_margin,
            margin_analysis.margin_volatility,
            margin_analysis.var_confidence_level * 100,
            margin_analysis.var_at_confidence,
            margin_analysis.expected_shortfall,
            margin_analysis.raroc * 100,
            margin_analysis.break_even_coupon * 100,
            margin_analysis.competitive_benchmark * 100,
            margin_analysis.market_competitiveness
        ]
    )

    margin_file = joinpath(output_dir, "bank_margin_analysis.csv")
    CSV.write(margin_file, margin_summary)
    println("🏦 Análise de margem bancária salva: $margin_file")

    # Scenario analysis breakdown
    scenarios_file = nothing
    if !isempty(margin_analysis.scenarios)
        scenarios_data = DataFrame(
            scenario = collect(keys(margin_analysis.scenarios)),
            margin_brl = collect(values(margin_analysis.scenarios))
        )
        scenarios_file = joinpath(output_dir, "margin_scenarios.csv")
        CSV.write(scenarios_file, scenarios_data)
        println("📊 Cenários de margem salvos: $scenarios_file")
    end

    return (margin_file, scenarios_file)
end

"""
    save_margin_sensitivity(sensitivity_results::Dict{Symbol, Vector{Float64}}, output_dir::String)

Save margin sensitivity analysis results.
"""
function save_margin_sensitivity(sensitivity_results::Dict{Symbol, Vector{Float64}}, output_dir::String)
    sensitivity_data = []

    for (factor, margins) in sensitivity_results
        for (i, margin) in enumerate(margins)
            push!(sensitivity_data, (
                risk_factor = string(factor),
                scenario_index = i,
                margin_brl = margin
            ))
        end
    end

    sensitivity_df = DataFrame(sensitivity_data)
    sensitivity_file = joinpath(output_dir, "margin_sensitivity.csv")
    CSV.write(sensitivity_file, sensitivity_df)
    println("📈 Análise de sensibilidade salva: $sensitivity_file")
    return sensitivity_file
end

"""
    generate_bank_margin_report(margin_analysis::BankMarginAnalysis, specs::Vector{UnderlyingSpec},
                                config::AutocallConfig, output_dir::String)

Generate comprehensive bank margin analysis report in markdown.
"""
function generate_bank_margin_report(margin_analysis::BankMarginAnalysis, specs::Vector{UnderlyingSpec},
                                    config::AutocallConfig, output_dir::String)
    report_file = joinpath(output_dir, "bank_margin_report.md")

    open(report_file, "w") do io
        write(io, "# Análise de Margem Bancária - COE Autocall\n\n")
        write(io, "**Data de análise:** $(Dates.format(now(), "dd/mm/yyyy HH:MM:SS"))\n\n")

        # Executive Summary
        write(io, "## Resumo Executivo\n\n")
        write(io, "| Métrica | Valor |\n")
        write(io, "|---------|-------|\n")
        write(io, "| **Cupom Oferecido** | $(round(margin_analysis.offered_coupon*100, digits=1))% semestral |\n")
        write(io, "| **Cupom Justo** | $(round(margin_analysis.fair_coupon*100, digits=1))% semestral |\n")
        write(io, "| **Spread Bruto** | $(round(margin_analysis.gross_spread*100, digits=1)) p.p. |\n")
        write(io, "| **Margem Absoluta** | R\$ $(round(margin_analysis.margin_absolute, digits=2)) |\n")
        write(io, "| **Margem Líquida** | R\$ $(round(margin_analysis.net_margin, digits=2)) |\n")
        write(io, "| **RAROC** | $(round(margin_analysis.raroc*100, digits=1))% |\n")
        write(io, "| **Competitividade** | $(margin_analysis.market_competitiveness) |\n\n")

        # Detailed Analysis
        write(io, "## Análise Detalhada\n\n")

        write(io, "### Decomposição da Margem\n\n")
        write(io, "**Receitas:**\n")
        write(io, "- Preço de mercado (cupom 8,8%): R\$ $(round(margin_analysis.coe_market_price, digits=2))\n")
        write(io, "- Preço justo (cupom equilibrio): R\$ $(round(margin_analysis.fair_market_price, digits=2))\n")
        write(io, "- **Margem bruta**: R\$ $(round(margin_analysis.margin_absolute, digits=2))\n\n")

        write(io, "**Custos e Ajustes:**\n")
        principal = margin_analysis.principal
        years = config.horizon_days / 252.0
        op_costs = principal * margin_analysis.operational_costs * years
        risk_buffer = principal * margin_analysis.risk_buffer

        write(io, "- Custos operacionais ($(round(margin_analysis.operational_costs*100, digits=1))% a.a.): R\$ $(round(op_costs, digits=2))\n")
        write(io, "- Buffer de risco ($(round(margin_analysis.risk_buffer*100, digits=1))%): R\$ $(round(risk_buffer, digits=2))\n")
        write(io, "- Custo de capital: R\$ $(round(margin_analysis.capital_cost, digits=2))\n")
        write(io, "- **Margem líquida**: R\$ $(round(margin_analysis.net_margin, digits=2))\n\n")

        # Risk Analysis
        write(io, "### Análise de Risco\n\n")
        write(io, "| Métrica de Risco | Valor |\n")
        write(io, "|------------------|-------|\n")
        write(io, "| Volatilidade da Margem | R\$ $(round(margin_analysis.margin_volatility, digits=2)) |\n")
        write(io, "| VaR $(round(margin_analysis.var_confidence_level*100, digits=1))% | R\$ $(round(margin_analysis.var_at_confidence, digits=2)) |\n")
        write(io, "| Expected Shortfall | R\$ $(round(margin_analysis.expected_shortfall, digits=2)) |\n")
        write(io, "| RAROC | $(round(margin_analysis.raroc*100, digits=1))% |\n\n")

        # Scenario Analysis
        if !isempty(margin_analysis.scenarios)
            write(io, "### Análise de Cenários\n\n")
            write(io, "| Cenário | Margem Líquida | Variação vs Base |\n")
            write(io, "|---------|----------------|------------------|\n")

            base_margin = get(margin_analysis.scenarios, :base, margin_analysis.net_margin)
            for (scenario, margin) in margin_analysis.scenarios
                variation = ((margin - base_margin) / base_margin) * 100
                write(io, "| $(uppercasefirst(string(scenario))) | R\$ $(round(margin, digits=2)) | $(round(variation, digits=1))% |\n")
            end
            write(io, "\n")
        end

        # Competitive Analysis
        write(io, "### Análise Competitiva\n\n")
        write(io, "- **Benchmark (CDI + spread)**: $(round(margin_analysis.competitive_benchmark*100, digits=1))% semestral\n")
        write(io, "- **Cupom oferecido**: $(round(margin_analysis.offered_coupon*100, digits=1))% semestral\n")
        write(io, "- **Avaliação**: $(margin_analysis.market_competitiveness)\n\n")

        cdi_spread = margin_analysis.offered_coupon - margin_analysis.competitive_benchmark
        write(io, "O cupom oferecido de $(round(margin_analysis.offered_coupon*100, digits=1))% representa um spread de ")
        write(io, "$(round(cdi_spread*100, digits=1)) p.p. sobre o benchmark CDI+spread.\n\n")

        # Recommendations
        write(io, "## Recomendações\n\n")

        if margin_analysis.net_margin > 0
            write(io, "✅ **Margem Positiva**: O produto apresenta margem líquida positiva de ")
            write(io, "R\$ $(round(margin_analysis.net_margin, digits=2)), representando ")
            write(io, "$(round(margin_analysis.net_margin/principal*100, digits=1))% do principal.\n\n")
        else
            write(io, "⚠️ **Margem Negativa**: O produto apresenta margem líquida negativa de ")
            write(io, "R\$ $(round(abs(margin_analysis.net_margin), digits=2)). Recomenda-se ")
            write(io, "revisão do cupom oferecido.\n\n")
        end

        if margin_analysis.raroc < 0.15
            write(io, "📊 **RAROC Baixo**: RAROC de $(round(margin_analysis.raroc*100, digits=1))% está ")
            write(io, "abaixo do custo de capital estimado. Considere ajuste no cupom.\n\n")
        end

        write(io, "### Cupom de Breakeven\n\n")
        write(io, "- **Cupom justo (margem zero)**: $(round(margin_analysis.break_even_coupon*100, digits=1))%\n")
        write(io, "- **Margem sobre breakeven**: $(round((margin_analysis.offered_coupon - margin_analysis.break_even_coupon)*100, digits=1)) p.p.\n\n")

        write(io, "---\n\n")
        write(io, "*Relatório gerado automaticamente pelo COE Autocall Pricer - Módulo de Análise Bancária*\n")
    end

    println("📋 Relatório de margem bancária gerado: $report_file")
    return report_file
end

"""
    export_bank_margin_results(margin_analysis::BankMarginAnalysis, sensitivity_results,
                               specs::Vector{UnderlyingSpec}, config::AutocallConfig, output_dir::String;
                               format::Symbol=:markdown)

Export complete bank margin analysis including sensitivity results.
Format options: :markdown (default), :html, :both
"""
function export_bank_margin_results(margin_analysis::BankMarginAnalysis, sensitivity_results,
                                   specs::Vector{UnderlyingSpec}, config::AutocallConfig, output_dir::String;
                                   format::Symbol=:markdown)
    println("🏦 Exportando análise completa de margem bancária...")
    println("  • Formato: $format")

    mkpath(output_dir)

    # Save margin analysis (always CSV data)
    save_bank_margin_analysis(margin_analysis, output_dir)

    # Save sensitivity analysis if available
    if !isnothing(sensitivity_results)
        save_margin_sensitivity(sensitivity_results, output_dir)
    end

    # Generate reports based on format
    if format == :markdown || format == :both
        generate_bank_margin_report(margin_analysis, specs, config, output_dir)
    end

    if format == :html || format == :both
        # Load HTML report module dynamically
        try
            include(joinpath(@__DIR__, "margin_html_reports.jl"))
            Base.invokelatest(generate_html_margin_report, margin_analysis, specs, config, output_dir)
        catch e
            println("⚠️  Erro ao gerar relatório HTML de margem: $e")
            println("   Verifique se as dependências estão instaladas: PlotlyJS, JSON3")
        end
    end

    println("✅ Export de margem bancária concluído!")
    return output_dir
end

export create_results_directory, save_simulation_summary, save_payoff_distribution,
       save_survival_probabilities, save_detailed_samples, generate_simulation_report,
       export_simulation_results, save_bank_margin_analysis, save_margin_sensitivity,
       generate_bank_margin_report, export_bank_margin_results
