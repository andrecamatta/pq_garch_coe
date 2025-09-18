"""
# Margin HTML Reports Module

Functions to generate interactive HTML reports for bank margin analysis.
"""

using PlotlyJS, JSON3, Dates, Printf, Statistics
include(joinpath(@__DIR__, "html_reports.jl"))
include(joinpath(@__DIR__, "financial_plots.jl"))

"""
    generate_html_margin_report(margin_analysis::BankMarginAnalysis, specs::Vector{UnderlyingSpec},
                               config::AutocallConfig, output_dir::String)

Generate comprehensive HTML margin analysis report with interactive dashboard.
"""
function generate_html_margin_report(margin_analysis::BankMarginAnalysis, specs::Vector{UnderlyingSpec},
                                    config::AutocallConfig, output_dir::String)

    println("🏦 Gerando relatório HTML de margem bancária...")

    # Generate interactive charts
    println("  • Criando gráfico RAROC...")
    raroc_plot = create_raroc_gauge(margin_analysis.raroc, 0.15, "RAROC vs Custo de Capital (15%)")
    raroc_json = JSON3.write(raroc_plot)

    println("  • Criando decomposição de margem...")
    costs_dict = Dict(
        "Custos Operacionais" => margin_analysis.principal * margin_analysis.operational_costs * (config.horizon_days / 252.0),
        "Buffer de Risco" => margin_analysis.principal * margin_analysis.risk_buffer,
        "Custo de Capital" => margin_analysis.capital_cost
    )
    margin_plot = create_margin_waterfall(margin_analysis.principal, margin_analysis.coe_market_price,
                                         costs_dict, "Decomposição da Margem Bancária")
    margin_json = JSON3.write(margin_plot)

    println("  • Criando análise competitiva...")
    competitive_plot = create_competitive_analysis_chart(margin_analysis)
    competitive_json = JSON3.write(competitive_plot)

    # Build HTML content
    content = build_margin_html_content(
        margin_analysis, specs, config, raroc_json, margin_json, competitive_json
    )

    # Read template and substitute
    template_path = joinpath(@__DIR__, "html_templates", "base_template.html")
    template = read(template_path, String)

    # Prepare template variables
    variables = Dict(
        "title" => "Análise de Margem Bancária - COE Autocall",
        "report_title" => "Bank Margin Analysis",
        "main_title" => "Análise de Margem Bancária",
        "subtitle" => "COE Autocall - Cupom $(round(margin_analysis.offered_coupon*100, digits=1))% semestral",
        "generation_date" => Dates.format(now(), "dd/mm/yyyy HH:MM"),
        "content" => content,
        "report_filename" => "margin_analysis_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS"))",
        "processing_time" => "Análise de rentabilidade bancária",
        "additional_scripts" => ""
    )

    # Simple template substitution
    html_content = template
    for (key, value) in variables
        html_content = replace(html_content, "{{$key}}" => value)
    end

    # Save report
    report_file = joinpath(output_dir, "margin_analysis.html")
    open(report_file, "w") do io
        write(io, html_content)
    end

    println("✅ Relatório HTML de margem salvo: $report_file")
    return report_file
end

"""
    build_margin_html_content(margin_analysis, specs, config, raroc_json, margin_json, competitive_json)

Build the main content section for margin report.
"""
function build_margin_html_content(margin_analysis, specs, config, raroc_json, margin_json, competitive_json)

    # Status badge based on margin
    margin_status = if margin_analysis.net_margin > 0
        """<span class="badge bg-success fs-6">
             <i class="fas fa-check-circle me-1"></i>MARGEM POSITIVA
           </span>"""
    else
        """<span class="badge bg-danger fs-6">
             <i class="fas fa-exclamation-triangle me-1"></i>MARGEM NEGATIVA
           </span>"""
    end

    raroc_status = if margin_analysis.raroc > 0.15
        """<span class="badge bg-success ms-2">
             <i class="fas fa-thumbs-up me-1"></i>RAROC ADEQUADO
           </span>"""
    else
        """<span class="badge bg-warning text-dark ms-2">
             <i class="fas fa-exclamation-circle me-1"></i>RAROC BAIXO
           </span>"""
    end

    # Key metrics cards
    metrics_html = """
    <div class="row mb-4">
        $(create_metric_card("Margem Líquida", margin_analysis.net_margin, :currency,
                           "$(round(margin_analysis.net_margin/margin_analysis.principal*100, digits=1))% do principal"))
        $(create_metric_card("RAROC", margin_analysis.raroc, :percentage, "vs 15% custo capital"))
        $(create_metric_card("Spread Bruto", margin_analysis.gross_spread, :percentage, "Cupom oferecido vs justo"))
        $(create_metric_card("Margem %", margin_analysis.net_margin/margin_analysis.principal, :percentage, "Sobre principal"))
    </div>
    """

    # Executive summary
    executive_summary = build_executive_summary(margin_analysis, margin_status, raroc_status)

    # Detailed breakdown
    detailed_breakdown = build_detailed_breakdown(margin_analysis, config)

    # Risk analysis
    risk_analysis = build_risk_analysis(margin_analysis)

    # Recommendations
    recommendations = build_recommendations(margin_analysis)

    # Competitive analysis
    competitive_analysis = build_competitive_analysis(margin_analysis)

    return """
    <!-- Status Overview -->
    <section id="status" class="mb-5">
        <div class="alert alert-light border">
            <div class="row align-items-center">
                <div class="col-md-8">
                    <h4 class="alert-heading mb-2">
                        <i class="fas fa-chart-line me-2"></i>Status da Análise
                    </h4>
                    <p class="mb-2">
                        $margin_status
                        $raroc_status
                    </p>
                    <small class="text-muted">
                        Análise baseada no cupom oferecido de $(round(margin_analysis.offered_coupon*100, digits=1))%
                        vs cupom justo de $(round(margin_analysis.fair_coupon*100, digits=1))%
                    </small>
                </div>
                <div class="col-md-4 text-end">
                    <h2 class="$(get_metric_class(margin_analysis.net_margin)) mb-0">
                        $(format_currency(margin_analysis.net_margin))
                    </h2>
                    <small class="text-muted">Margem Líquida</small>
                </div>
            </div>
        </div>
    </section>

    <!-- Key Metrics -->
    <section id="metrics" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-tachometer-alt me-2"></i>Métricas Principais
        </h2>
        $metrics_html
    </section>

    <!-- Executive Summary -->
    <section id="executive-summary" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-clipboard-list me-2"></i>Resumo Executivo
        </h2>
        <div class="chart-container">
            $executive_summary
        </div>
    </section>

    <!-- Interactive Charts -->
    <section id="charts" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-chart-pie me-2"></i>Análise Visual
        </h2>

        <div class="row">
            <div class="col-lg-6 mb-4">
                <div id="raroc-chart" class="chart-container" style="height: 400px;">
                    <h5 class="text-center mb-3">RAROC Performance</h5>
                </div>
            </div>
            <div class="col-lg-6 mb-4">
                <div id="margin-chart" class="chart-container" style="height: 400px;">
                    <h5 class="text-center mb-3">Decomposição de Margem</h5>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-12 mb-4">
                <div id="competitive-chart" class="chart-container" style="height: 400px;">
                    <h5 class="text-center mb-3">Análise Competitiva</h5>
                </div>
            </div>
        </div>
    </section>

    <!-- Detailed Analysis -->
    <section id="detailed-analysis" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-microscope me-2"></i>Análise Detalhada
        </h2>
        <div class="chart-container">
            $detailed_breakdown
        </div>
    </section>

    <!-- Risk Analysis -->
    <section id="risk" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-shield-alt me-2"></i>Análise de Risco
        </h2>
        <div class="chart-container">
            $risk_analysis
        </div>
    </section>

    <!-- Competitive Analysis -->
    <section id="competitive" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-balance-scale me-2"></i>Posicionamento Competitivo
        </h2>
        <div class="chart-container">
            $competitive_analysis
        </div>
    </section>

    <!-- Recommendations -->
    <section id="recommendations" class="mb-5">
        <h2 class="section-title">
            <i class="fas fa-lightbulb me-2"></i>Recomendações
        </h2>
        <div class="chart-container">
            $recommendations
        </div>
    </section>

    <script>
        // Initialize charts
        document.addEventListener('DOMContentLoaded', function() {
            // RAROC gauge
            const rarocData = $raroc_json;
            Plotly.newPlot('raroc-chart', rarocData.data, rarocData.layout, {responsive: true});

            // Margin waterfall
            const marginData = $margin_json;
            Plotly.newPlot('margin-chart', marginData.data, marginData.layout, {responsive: true});

            // Competitive analysis
            const competitiveData = $competitive_json;
            Plotly.newPlot('competitive-chart', competitiveData.data, competitiveData.layout, {responsive: true});
        });
    </script>
    """
end

"""
    build_executive_summary(margin_analysis, margin_status, raroc_status)

Build executive summary section.
"""
function build_executive_summary(margin_analysis, margin_status, raroc_status)
    margin_pct = round(margin_analysis.net_margin / margin_analysis.principal * 100, digits=1)

    return """
    <div class="row">
        <div class="col-md-8">
            <h5>Resumo da Análise</h5>
            <table class="table table-borderless">
                <tr>
                    <td class="fw-bold">Cupom Oferecido:</td>
                    <td>$(round(margin_analysis.offered_coupon*100, digits=1))% semestral</td>
                </tr>
                <tr>
                    <td class="fw-bold">Cupom Justo:</td>
                    <td>$(round(margin_analysis.fair_coupon*100, digits=1))% semestral</td>
                </tr>
                <tr>
                    <td class="fw-bold">Spread Bruto:</td>
                    <td class="$(get_metric_class(margin_analysis.gross_spread))">
                        $(round(margin_analysis.gross_spread*100, digits=1)) p.p.
                    </td>
                </tr>
                <tr>
                    <td class="fw-bold">Margem Líquida:</td>
                    <td class="$(get_metric_class(margin_analysis.net_margin))">
                        $(format_currency(margin_analysis.net_margin)) ($(margin_pct)% do principal)
                    </td>
                </tr>
                <tr>
                    <td class="fw-bold">RAROC:</td>
                    <td class="$(get_metric_class(margin_analysis.raroc - 0.15))">
                        $(round(margin_analysis.raroc*100, digits=1))% vs 15% custo capital
                    </td>
                </tr>
            </table>
        </div>
        <div class="col-md-4">
            <h5>Avaliação</h5>
            <div class="d-grid gap-2">
                $margin_status
                $raroc_status
                <span class="badge bg-info">
                    <i class="fas fa-star me-1"></i>$(margin_analysis.market_competitiveness)
                </span>
            </div>
        </div>
    </div>
    """
end

"""
    build_detailed_breakdown(margin_analysis, config)

Build detailed margin breakdown.
"""
function build_detailed_breakdown(margin_analysis, config)
    years = config.horizon_days / 252.0
    op_costs = margin_analysis.principal * margin_analysis.operational_costs * years
    risk_buffer = margin_analysis.principal * margin_analysis.risk_buffer

    return """
    <div class="row">
        <div class="col-md-6">
            <h5>Receitas e Custos</h5>
            <table class="table table-sm">
                <tr class="table-light">
                    <td><strong>Principal Recebido</strong></td>
                    <td class="text-end">$(format_currency(margin_analysis.principal))</td>
                </tr>
                <tr>
                    <td>(-) Custo de Hedge</td>
                    <td class="text-end text-danger">$(format_currency(margin_analysis.coe_market_price))</td>
                </tr>
                <tr class="table-success">
                    <td><strong>= Margem Bruta</strong></td>
                    <td class="text-end fw-bold">$(format_currency(margin_analysis.margin_absolute))</td>
                </tr>
                <tr>
                    <td>(-) Custos Operacionais</td>
                    <td class="text-end text-warning">$(format_currency(op_costs))</td>
                </tr>
                <tr>
                    <td>(-) Buffer de Risco</td>
                    <td class="text-end text-warning">$(format_currency(risk_buffer))</td>
                </tr>
                <tr>
                    <td>(-) Custo de Capital</td>
                    <td class="text-end text-warning">$(format_currency(margin_analysis.capital_cost))</td>
                </tr>
                <tr class="table-primary">
                    <td><strong>= Margem Líquida</strong></td>
                    <td class="text-end fw-bold $(get_metric_class(margin_analysis.net_margin))">
                        $(format_currency(margin_analysis.net_margin))
                    </td>
                </tr>
            </table>
        </div>
        <div class="col-md-6">
            <h5>Parâmetros de Custo</h5>
            <table class="table table-sm">
                <tr>
                    <td>Taxa Operacional</td>
                    <td class="text-end">$(round(margin_analysis.operational_costs*100, digits=1))% a.a.</td>
                </tr>
                <tr>
                    <td>Buffer de Risco</td>
                    <td class="text-end">$(round(margin_analysis.risk_buffer*100, digits=1))%</td>
                </tr>
                <tr>
                    <td>Capital Regulatório</td>
                    <td class="text-end">$(round(margin_analysis.competitive_benchmark*100, digits=1))%</td>
                </tr>
                <tr>
                    <td>Custo de Capital</td>
                    <td class="text-end">15.0% a.a.</td>
                </tr>
                <tr>
                    <td>Prazo do Produto</td>
                    <td class="text-end">$(round(years, digits=1)) anos</td>
                </tr>
            </table>
        </div>
    </div>
    """
end

"""
    build_risk_analysis(margin_analysis)

Build risk analysis section.
"""
function build_risk_analysis(margin_analysis)
    return """
    <div class="row">
        <div class="col-md-6">
            <h5>Métricas de Risco</h5>
            <table class="table table-sm">
                <tr>
                    <td><strong>VaR $(round(margin_analysis.var_confidence_level*100, digits=1))%</strong></td>
                    <td class="text-end">$(format_currency(margin_analysis.var_at_confidence))</td>
                </tr>
                <tr>
                    <td><strong>Expected Shortfall</strong></td>
                    <td class="text-end">$(format_currency(margin_analysis.expected_shortfall))</td>
                </tr>
                <tr>
                    <td><strong>Volatilidade da Margem</strong></td>
                    <td class="text-end">$(format_currency(margin_analysis.margin_volatility))</td>
                </tr>
                <tr>
                    <td><strong>RAROC</strong></td>
                    <td class="text-end $(get_metric_class(margin_analysis.raroc - 0.15))">
                        $(round(margin_analysis.raroc*100, digits=1))%
                    </td>
                </tr>
            </table>
        </div>
        <div class="col-md-6">
            <h5>Interpretação</h5>
            <ul class="list-unstyled">
                $(margin_analysis.raroc > 0.15 ?
                  "<li><i class=\"fas fa-check text-success me-2\"></i>RAROC acima do custo de capital</li>" :
                  "<li><i class=\"fas fa-times text-danger me-2\"></i>RAROC abaixo do custo de capital</li>")
                $(margin_analysis.net_margin > 0 ?
                  "<li><i class=\"fas fa-check text-success me-2\"></i>Margem líquida positiva</li>" :
                  "<li><i class=\"fas fa-times text-danger me-2\"></i>Margem líquida negativa</li>")
                <li><i class="fas fa-info text-info me-2"></i>Produto $(margin_analysis.market_competitiveness) no mercado</li>
            </ul>
        </div>
    </div>
    """
end

"""
    build_competitive_analysis(margin_analysis)

Build competitive analysis section.
"""
function build_competitive_analysis(margin_analysis)
    benchmark_spread = margin_analysis.offered_coupon - margin_analysis.competitive_benchmark

    return """
    <div class="row">
        <div class="col-md-6">
            <h5>Posicionamento vs Mercado</h5>
            <table class="table table-sm">
                <tr>
                    <td><strong>Cupom Oferecido</strong></td>
                    <td class="text-end">$(round(margin_analysis.offered_coupon*100, digits=1))%</td>
                </tr>
                <tr>
                    <td><strong>Benchmark (CDI + spread)</strong></td>
                    <td class="text-end">$(round(margin_analysis.competitive_benchmark*100, digits=1))%</td>
                </tr>
                <tr>
                    <td><strong>Spread vs Benchmark</strong></td>
                    <td class="text-end $(get_metric_class(benchmark_spread, false))">
                        $(round(benchmark_spread*100, digits=1)) p.p.
                    </td>
                </tr>
                <tr>
                    <td><strong>Avaliação</strong></td>
                    <td class="text-end">
                        <span class="badge bg-info">$(margin_analysis.market_competitiveness)</span>
                    </td>
                </tr>
            </table>
        </div>
        <div class="col-md-6">
            <h5>Breakeven Analysis</h5>
            <table class="table table-sm">
                <tr>
                    <td><strong>Cupom de Breakeven</strong></td>
                    <td class="text-end">$(round(margin_analysis.break_even_coupon*100, digits=1))%</td>
                </tr>
                <tr>
                    <td><strong>Margem sobre Breakeven</strong></td>
                    <td class="text-end $(get_metric_class(margin_analysis.offered_coupon - margin_analysis.break_even_coupon))">
                        $(round((margin_analysis.offered_coupon - margin_analysis.break_even_coupon)*100, digits=1)) p.p.
                    </td>
                </tr>
            </table>
        </div>
    </div>
    """
end

"""
    build_recommendations(margin_analysis)

Build recommendations section.
"""
function build_recommendations(margin_analysis)
    if margin_analysis.net_margin > 0 && margin_analysis.raroc > 0.15
        recommendation_class = "alert-success"
        icon = "fas fa-thumbs-up"
        title = "Produto Recomendado"
        text = "O produto apresenta margem líquida positiva e RAROC adequado. Recomenda-se prosseguir com a oferta."
    elseif margin_analysis.net_margin > 0
        recommendation_class = "alert-warning"
        icon = "fas fa-exclamation-triangle"
        title = "Margem Adequada, RAROC Baixo"
        text = "Embora a margem seja positiva, o RAROC está abaixo do custo de capital. Considere ajustar custos ou precificação."
    else
        recommendation_class = "alert-danger"
        icon = "fas fa-times-circle"
        title = "Produto Não Recomendado"
        text = "Margem líquida negativa. Recomenda-se revisão completa da estrutura de custos e precificação."
    end

    return """
    <div class="alert $recommendation_class">
        <h5 class="alert-heading">
            <i class="$icon me-2"></i>$title
        </h5>
        <p class="mb-0">$text</p>
    </div>

    <div class="row mt-3">
        <div class="col-md-6">
            <h6>Ações Sugeridas:</h6>
            <ul>
                $(margin_analysis.net_margin <= 0 ?
                  "<li>Revisar cupom oferecido para aumentar margem</li>" : "")
                $(margin_analysis.raroc <= 0.15 ?
                  "<li>Analisar redução de custos operacionais</li>" : "")
                <li>Monitorar mudanças nas condições de mercado</li>
                <li>Acompanhar performance vs benchmarks</li>
            </ul>
        </div>
        <div class="col-md-6">
            <h6>Pontos de Atenção:</h6>
            <ul>
                <li>Volatilidade dos ativos subjacentes</li>
                <li>Mudanças nas taxas de juros</li>
                <li>Pressão competitiva no mercado</li>
                <li>Regulamentações bancárias</li>
            </ul>
        </div>
    </div>
    """
end

"""
    create_competitive_analysis_chart(margin_analysis)

Create competitive analysis chart.
"""
function create_competitive_analysis_chart(margin_analysis)
    categories = ["Cupom Oferecido", "Cupom Justo", "Benchmark CDI+"]
    values = [
        margin_analysis.offered_coupon * 100,
        margin_analysis.fair_coupon * 100,
        margin_analysis.competitive_benchmark * 100
    ]
    colors = [FINANCIAL_COLORS.neutral, FINANCIAL_COLORS.negative, FINANCIAL_COLORS.highlight]

    trace = bar(
        x=categories,
        y=values,
        marker=attr(color=colors, opacity=0.8),
        hovertemplate="<b>%{x}:</b><br><b>Taxa:</b> %{y:.1f}%<extra></extra>"
    )

    layout = Layout(
        title="Comparação de Cupons e Benchmarks",
        xaxis=attr(title="Métricas"),
        yaxis=attr(title="Taxa (%)", tickformat=".1f"),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)",
        showlegend=false
    )

    return plot([trace], layout)
end

# Export main function
export generate_html_margin_report
