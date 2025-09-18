"""
# Simulation HTML Reports Module

Functions to generate interactive HTML reports for COE Autocall simulation results.
"""

using PlotlyJS, JSON3, Dates, Printf, Statistics
include(joinpath(@__DIR__, "html_reports.jl"))
include(joinpath(@__DIR__, "financial_plots.jl"))

"""
    generate_html_simulation_report(result, specs::Vector{UnderlyingSpec},
                                   config::AutocallConfig, output_dir::String)

Generate comprehensive HTML simulation report with interactive charts.
"""
function generate_html_simulation_report(result, specs::Vector{UnderlyingSpec},
                                        config::AutocallConfig, output_dir::String)

    println("📊 Gerando relatório HTML de simulação...")

    # Extract data
    payoffs = result.pv_brl
    autocall_periods = if haskey(result, :autocall_periods)
        result.autocall_periods
    elseif haskey(result, :detailed_samples) && !isempty(result.detailed_samples)
        [sample.autocall_period for sample in result.detailed_samples]
    else
        Int[]
    end

    # Calculate statistics
    mean_payoff = mean(payoffs)
    std_payoff = std(payoffs)
    min_payoff = minimum(payoffs)
    max_payoff = maximum(payoffs)
    autocall_rate = isempty(autocall_periods) ? 0.0 : count(p -> p > 0, autocall_periods) / length(autocall_periods)

    # Generate plots
    println("  • Criando gráfico de distribuição de payoffs...")
    payoff_plot = create_payoff_histogram(payoffs, "Distribuição de Payoffs (Valor Presente)")
    payoff_json = JSON3.write(payoff_plot)

    println("  • Criando timeline de autocalls...")
    autocall_plot = create_autocall_timeline(autocall_periods,
                                           collect(config.obs_spacing_days:config.obs_spacing_days:config.horizon_days),
                                           "Probabilidade de Autocall por Semestre")
    autocall_json = JSON3.write(autocall_plot)

    # Survival probabilities
    n_observations = length(config.coupons)
    survival_probs = Float64[]
    if isempty(autocall_periods)
        survival_probs = fill(0.0, n_observations)
    else
        for obs in 1:n_observations
            survived = count(p -> p == 0 || p > obs, autocall_periods)
            push!(survival_probs, survived / length(autocall_periods) * 100)
        end
    end

    # Create survival curve
    survival_plot = scatter(
        x=1:n_observations,
        y=survival_probs,
        mode="lines+markers",
        name="Probabilidade de Sobrevivência",
        line=attr(color=FINANCIAL_COLORS.neutral, width=3),
        marker=attr(size=8, color=FINANCIAL_COLORS.highlight)
    )

    survival_layout = Layout(
        title="Curva de Sobrevivência (Probabilidade de Não-Autocall)",
        xaxis=attr(title="Semestre", tickmode="linear", tick0=1, dtick=1),
        yaxis=attr(title="Probabilidade (%)", tickformat=".1f"),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)"
    )

    survival_chart = plot([survival_plot], survival_layout)
    survival_json = JSON3.write(survival_chart)

    # Build HTML content
    content = build_simulation_html_content(
        result, specs, config, payoff_json, autocall_json, survival_json,
        mean_payoff, std_payoff, min_payoff, max_payoff, autocall_rate
    )

    # Read template and substitute
    template_path = joinpath(@__DIR__, "html_templates", "base_template.html")
    template = read(template_path, String)

    # Prepare template variables
    variables = Dict(
        "title" => "Relatório de Simulação COE Autocall",
        "report_title" => "COE Autocall Simulation",
        "main_title" => "Análise de Simulação Monte Carlo",
        "subtitle" => "COE Autocall com $(length(specs)) ativos subjacentes",
        "generation_date" => Dates.format(now(), "dd/mm/yyyy HH:MM"),
        "content" => content,
        "report_filename" => "simulation_report_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS"))",
        "processing_time" => "$(length(result.pv_brl)) simulações",
        "additional_scripts" => ""
    )

    # Simple template substitution
    html_content = template
    for (key, value) in variables
        html_content = replace(html_content, "{{$key}}" => value)
    end

    # Save report
    report_file = joinpath(output_dir, "simulation_report.html")
    open(report_file, "w") do io
        write(io, html_content)
    end

    println("✅ Relatório HTML de simulação salvo: $report_file")
    return report_file
end

"""
    build_simulation_html_content(result, specs, config, payoff_json, autocall_json,
                                 survival_json, mean_payoff, std_payoff, min_payoff,
                                 max_payoff, autocall_rate)

Build the main content section for simulation report.
"""
function build_simulation_html_content(result, specs, config, payoff_json, autocall_json,
                                      survival_json, mean_payoff, std_payoff, min_payoff,
                                      max_payoff, autocall_rate)

    # Key metrics cards
    metrics_html = """
    <div class="row mb-4">
        $(create_metric_card("Preço Médio", mean_payoff, :currency, "Valor presente esperado"))
        $(create_metric_card("Volatilidade", std_payoff, :currency, "Desvio padrão"))
        $(create_metric_card("Taxa de Autocall", autocall_rate, :percentage, "Probabilidade de exercício"))
        $(create_metric_card("Range", max_payoff - min_payoff, :currency, "Amplitude total"))
    </div>
    """

    # Configuration table
    config_table = build_configuration_table(specs, config)

    # Detailed samples table (first 10)
    samples_table = build_samples_table(result.detailed_samples, specs, config)

    # Statistics table
    stats_table = build_statistics_table(mean_payoff, std_payoff, min_payoff, max_payoff,
                                        result.confidence_interval, autocall_rate)

    return """
    <!-- Executive Summary -->
    <section id="summary" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-chart-bar me-2"></i>Resumo Executivo
        </h2>
        $metrics_html
    </section>

    <!-- Configuration -->
    <section id="configuration" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-cogs me-2"></i>Configuração da Simulação
        </h2>
        <div class="chart-container">
            $config_table
        </div>
    </section>

    <!-- Charts -->
    <section id="charts" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-chart-line me-2"></i>Análise Visual
        </h2>

        <div class="row">
            <div class="col-lg-6 mb-4">
                <div id="payoff-chart" class="chart-container" style="height: 400px;"></div>
            </div>
            <div class="col-lg-6 mb-4">
                <div id="autocall-chart" class="chart-container" style="height: 400px;"></div>
            </div>
        </div>

        <div class="row">
            <div class="col-12 mb-4">
                <div id="survival-chart" class="chart-container" style="height: 400px;"></div>
            </div>
        </div>
    </section>

    <!-- Statistics -->
    <section id="statistics" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-calculator me-2"></i>Estatísticas Detalhadas
        </h2>
        <div class="chart-container">
            $stats_table
        </div>
    </section>

    <!-- Sample Details -->
    <section id="samples" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-list-ul me-2"></i>Amostras Detalhadas
        </h2>
        <div class="chart-container">
            <p class="text-muted mb-3">
                Primeiros 10 paths da simulação com detalhamento completo de cada trajetória.
            </p>
            $samples_table
        </div>
    </section>

    <script>
        // Initialize charts
        document.addEventListener('DOMContentLoaded', function() {
            // Payoff distribution
            const payoffData = $payoff_json;
            Plotly.newPlot('payoff-chart', payoffData.data, payoffData.layout, {responsive: true});

            // Autocall timeline
            const autocallData = $autocall_json;
            Plotly.newPlot('autocall-chart', autocallData.data, autocallData.layout, {responsive: true});

            // Survival curve
            const survivalData = $survival_json;
            Plotly.newPlot('survival-chart', survivalData.data, survivalData.layout, {responsive: true});
        });
    </script>
    """
end

"""
    build_configuration_table(specs, config)

Build configuration summary table.
"""
function build_configuration_table(specs, config)
    assets_html = join([
        "<li><strong>$(spec.symbol):</strong> \$$(spec.price0) " *
        (spec.has_dividend_yield ? "(div: $(round(spec.dividend_yield*100, digits=1))%)" : "") *
        "</li>"
        for spec in specs
    ], "")

    return """
    <div class="row">
        <div class="col-md-6">
            <h5>Parâmetros do Produto</h5>
            <table class="table table-sm">
                <tr><td><strong>Principal</strong></td><td>$(format_currency(config.principal))</td></tr>
                <tr><td><strong>Prazo Total</strong></td><td>$(config.horizon_days) dias ($(round(config.horizon_days/252, digits=1)) anos)</td></tr>
                <tr><td><strong>Observações</strong></td><td>A cada $(config.obs_spacing_days) dias ($(length(config.coupons)) observações)</td></tr>
                <tr><td><strong>Cupom por Semestre</strong></td><td>$(format_percentage(config.coupons[1]))</td></tr>
                <tr><td><strong>Taxa FX Spot</strong></td><td>$(config.fx_spot) BRL/USD</td></tr>
            </table>
        </div>
        <div class="col-md-6">
            <h5>Ativos Subjacentes</h5>
            <ul class="list-unstyled">
                $assets_html
            </ul>
            <p class="small text-muted mt-3">
                <strong>Condição de Autocall:</strong> Todos os ativos devem estar ≥ preço inicial
            </p>
        </div>
    </div>
    """
end

"""
    build_samples_table(detailed_samples, specs, config)

Build table with detailed sample information.
"""
function build_samples_table(detailed_samples, specs, config)
    if isempty(detailed_samples)
        return "<p class=\"text-muted\">Nenhuma amostra detalhada disponível.</p>"
    end

    # Show first 10 samples
    max_samples = min(10, length(detailed_samples))

    rows_html = ""
    for i in 1:max_samples
        sample = detailed_samples[i]

        result_text = if sample.autocall_period > 0
            "<span class=\"badge bg-success\">Autocall S$(sample.autocall_period)</span>"
        else
            "<span class=\"badge bg-secondary\">Vencimento</span>"
        end

        payoff_class = sample.final_payoff_pv >= sample.initial_prices[1] ? "text-success" : "text-danger"

        rows_html *= """
        <tr>
            <td>$i</td>
            <td>$result_text</td>
            <td>$(sample.autocall_day > 0 ? sample.autocall_day : config.horizon_days)</td>
            <td class="$payoff_class">$(format_currency(sample.final_payoff_pv))</td>
            <td>$(format_currency(sample.final_payoff_nominal))</td>
            <td>$(round(sample.coupon_accrual*100, digits=1))%</td>
        </tr>
        """
    end

    return """
    <div class="table-responsive">
        <table class="table table-striped table-hover table-sm">
            <thead class="table-dark">
                <tr>
                    <th>Path</th>
                    <th>Resultado</th>
                    <th>Dia Final</th>
                    <th>Valor Presente</th>
                    <th>Payoff Nominal</th>
                    <th>Cupons Acum.</th>
                </tr>
            </thead>
            <tbody>
                $rows_html
            </tbody>
        </table>
    </div>
    """
end

"""
    build_statistics_table(mean_payoff, std_payoff, min_payoff, max_payoff, ci, autocall_rate)

Build comprehensive statistics table.
"""
function build_statistics_table(mean_payoff, std_payoff, min_payoff, max_payoff, ci, autocall_rate)
    return """
    <div class="row">
        <div class="col-md-6">
            <h5>Estatísticas dos Payoffs</h5>
            <table class="table table-sm">
                <tr><td><strong>Média</strong></td><td>$(format_currency(mean_payoff))</td></tr>
                <tr><td><strong>Desvio Padrão</strong></td><td>$(format_currency(std_payoff))</td></tr>
                <tr><td><strong>Mínimo</strong></td><td>$(format_currency(min_payoff))</td></tr>
                <tr><td><strong>Máximo</strong></td><td>$(format_currency(max_payoff))</td></tr>
                <tr><td><strong>Intervalo de Confiança 90%</strong></td><td>$(format_currency(ci[1])) - $(format_currency(ci[2]))</td></tr>
            </table>
        </div>
        <div class="col-md-6">
            <h5>Análise de Autocalls</h5>
            <table class="table table-sm">
                <tr><td><strong>Taxa de Autocall</strong></td><td>$(format_percentage(autocall_rate))</td></tr>
                <tr><td><strong>Taxa de Vencimento</strong></td><td>$(format_percentage(1-autocall_rate))</td></tr>
                <tr><td><strong>Coeficiente de Variação</strong></td><td>$(round(std_payoff/mean_payoff, digits=3))</td></tr>
            </table>
        </div>
    </div>
    """
end

# Export main function
export generate_html_simulation_report
