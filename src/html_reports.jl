"""
# HTML Reports Module

Module for generating beautiful, interactive HTML reports for COE Autocall analysis.
Includes support for:
- Interactive charts with PlotlyJS
- Responsive HTML templates
- Financial dashboard components
- Export capabilities

Dependencies:
- PlotlyJS.jl for interactive charts
- JSON3.jl for data serialization
- Mustache.jl for HTML templating
- Colors.jl for financial color schemes
"""

using Dates, Statistics, Printf

# Optional dependencies check
function check_plotlyjs()
    try
        eval(:(using PlotlyJS))
        return true
    catch
        return false
    end
end

function check_json3()
    try
        eval(:(using JSON3))
        return true
    catch
        return false
    end
end

# Color palette for financial reports - actual colors for Plotly charts
const FINANCIAL_COLORS = (
    positive = "#5cb85c",     # Green for positive margins/profits (works in both modes)
    negative = "#ff6b6b",     # Red for negative margins/losses (works in both modes)
    neutral = "#5bc0de",      # Blue for neutral metrics (works in both modes)
    highlight = "#ffd93d",    # Gold for key highlights (works in both modes)
    background = "#f8f9fa",   # Light gray background
    text_primary = "#212529", # Dark text
    text_secondary = "#6c757d" # Light text
)

# Bootstrap CSS classes for styling
const BOOTSTRAP_CLASSES = (
    card = "card shadow-sm mb-4",
    card_header = "card-header bg-primary text-white",
    card_body = "card-body",
    metric_positive = "text-success fw-bold",
    metric_negative = "text-danger fw-bold",
    metric_neutral = "text-primary fw-bold",
    table = "table table-striped table-hover",
    badge_success = "badge bg-success",
    badge_danger = "badge bg-danger",
    badge_info = "badge bg-info"
)

"""
    format_currency(value::Real; currency="R\$", decimals=2)

Format a number as currency with proper formatting.
"""
function format_currency(value::Real; currency="R\$", decimals=2)
    if abs(value) >= 1_000_000
        return @sprintf("%s %.1fM", currency, value / 1_000_000)
    elseif abs(value) >= 1_000
        return @sprintf("%s %.1fK", currency, value / 1_000)
    else
        return @sprintf("%s %.*f", currency, decimals, value)
    end
end

"""
    format_percentage(value::Real; decimals=1)

Format a number as percentage.
"""
function format_percentage(value::Real; decimals=1)
    return @sprintf("%.*f%%", decimals, value * 100)
end

"""
    get_metric_class(value::Real, is_positive_good::Bool=true)

Get Bootstrap CSS class based on whether metric is positive or negative.
"""
function get_metric_class(value::Real, is_positive_good::Bool=true)
    if value > 0
        return is_positive_good ? BOOTSTRAP_CLASSES.metric_positive : BOOTSTRAP_CLASSES.metric_negative
    elseif value < 0
        return is_positive_good ? BOOTSTRAP_CLASSES.metric_negative : BOOTSTRAP_CLASSES.metric_positive
    else
        return BOOTSTRAP_CLASSES.metric_neutral
    end
end

"""
    create_metric_card(title::String, value::Real, format_type::Symbol=:currency,
                      subtitle::String="", is_positive_good::Bool=true)

Create HTML card for displaying key metrics.
"""
function create_metric_card(title::String, value::Real, format_type::Symbol=:currency,
                           subtitle::String="", is_positive_good::Bool=true)

    formatted_value = if format_type == :currency
        format_currency(value)
    elseif format_type == :percentage
        format_percentage(value)
    else
        string(value)
    end

    css_class = get_metric_class(value, is_positive_good)

    subtitle_html = isempty(subtitle) ? "" : "<small class=\"text-muted\">$subtitle</small>"

    return """
    <div class="col-md-3 mb-3">
        <div class="$BOOTSTRAP_CLASSES.card">
            <div class="$BOOTSTRAP_CLASSES.card_body text-center">
                <h6 class="card-title text-muted mb-2">$title</h6>
                <h3 class="$css_class">$formatted_value</h3>
                $subtitle_html
            </div>
        </div>
    </div>
    """
end

"""
    generate_html_head(title::String)

Generate HTML head section with required CSS and JS libraries.
"""
function generate_html_head(title::String)
    return """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>$title</title>

        <!-- Bootstrap CSS -->
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css"
              rel="stylesheet"
              integrity="sha384-1BmE4kWBq78iYhFldvKuhfTAU6auU8tT94WrHftjDbrCEXSU1oBoqyl2QvZ6jIW3"
              crossorigin="anonymous">

        <!-- Plotly.js -->
        <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>

        <!-- Font Awesome for icons -->
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">

        <style>
            body {
                background-color: #f8f9fa;
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            }
            .navbar-brand {
                font-weight: bold;
            }
            .metric-card {
                transition: transform 0.2s;
            }
            .metric-card:hover {
                transform: translateY(-2px);
            }
            .chart-container {
                background: white;
                border-radius: 0.375rem;
                padding: 1rem;
                box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
            }
            .summary-table {
                font-size: 0.9rem;
            }
            .report-header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 2rem 0;
            }
            @media print {
                .no-print { display: none !important; }
            }
        </style>
    </head>
    """
end

"""
    generate_html_navbar(title::String)

Generate navigation bar for the report.
"""
function generate_html_navbar(title::String)
    return """
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="#">
                <i class="fas fa-chart-line me-2"></i>$title
            </a>
            <div class="navbar-nav ms-auto">
                <span class="navbar-text">
                    <i class="fas fa-calendar me-1"></i>$(Dates.format(now(), "dd/mm/yyyy HH:MM"))
                </span>
            </div>
        </div>
    </nav>
    """
end

"""
    generate_html_footer()

Generate footer for the report.
"""
function generate_html_footer()
    return """
    <footer class="bg-dark text-light py-4 mt-5">
        <div class="container text-center">
            <p class="mb-0">
                <i class="fas fa-robot me-2"></i>
                Relatório gerado automaticamente pelo COE Autocall Pricer
                <br>
                <small class="text-muted">Módulo de Análise Avançada - Versão HTML Interativa</small>
            </p>
        </div>
    </footer>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"
            integrity="sha384-ka7Sk0Gln4gmtz2MlQnikT1wXgYsOg+OMhuP+IlRH9sENBO0LRn5q+8nbTov4+1p"
            crossorigin="anonymous"></script>
    </body>
    </html>
    """
end

"""
    create_plotly_div(plot_json::String, div_id::String, height::Int=400)

Create a div container for Plotly charts.
"""
function create_plotly_div(plot_json::String, div_id::String, height::Int=400)
    return """
    <div id="$div_id" class="chart-container mb-4" style="height: $(height)px;"></div>
    <script>
        Plotly.newPlot('$div_id', $plot_json.data, $plot_json.layout, {responsive: true});
    </script>
    """
end

# Export main functions
export format_currency, format_percentage, get_metric_class, create_metric_card,
       generate_html_head, generate_html_navbar, generate_html_footer, create_plotly_div,
       FINANCIAL_COLORS, BOOTSTRAP_CLASSES