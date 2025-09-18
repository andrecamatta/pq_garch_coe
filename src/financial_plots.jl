"""
# Financial Plots Module

Module for creating interactive financial charts using PlotlyJS.
Specialized for COE Autocall analysis with:
- Payoff distribution histograms
- Autocall timeline charts
- Margin waterfall charts
- Sensitivity analysis heatmaps
- RAROC gauge charts
"""

using PlotlyJS, Statistics, Colors, Printf, StatsBase
include("html_reports.jl")

"""
    create_payoff_histogram(payoffs::Vector{Float64}, title::String="Distribuição de Payoffs")

Create interactive histogram of payoff distribution.
"""
function create_payoff_histogram(payoffs::Vector{Float64}, title::String="Distribuição de Payoffs")

    # Calculate statistics
    mean_payoff = mean(payoffs)
    std_payoff = std(payoffs)
    min_payoff = minimum(payoffs)
    max_payoff = maximum(payoffs)

    # Create histogram
    trace = histogram(
        x=payoffs,
        nbinsx=30,
        name="Payoffs",
        marker=attr(
            color=FINANCIAL_COLORS.neutral,
            opacity=0.7,
            line=attr(color="white", width=1)
        ),
        hovertemplate="<b>Valor:</b> %{x:,.2f}<br>" *
                     "<b>Frequência:</b> %{y}<br>" *
                     "<extra></extra>"
    )

    # Add mean line
    h = fit(Histogram, payoffs, nbins=30)
    max_count = maximum(h.weights)
    mean_line = scatter(
        x=[mean_payoff, mean_payoff],
        y=[0, max_count],
        mode="lines",
        name="Média",
        line=attr(color=FINANCIAL_COLORS.highlight, width=3, dash="dash"),
        hovertemplate="<b>Média:</b> R\$ %{x:,.2f}<extra></extra>"
    )

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        xaxis=attr(
            title="Valor (R\$)",
            tickformat=",.0f",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        yaxis=attr(
            title="Frequência",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)",
        hovermode="closest",
        showlegend=true,
        legend=attr(x=0.7, y=0.9),
        annotations=[
            attr(
                text=@sprintf("Média: R\$ %.2f<br>Desvio: R\$ %.2f<br>Min: R\$ %.2f<br>Max: R\$ %.2f",
                             mean_payoff, std_payoff, min_payoff, max_payoff),
                x=0.02, y=0.98,
                xref="paper", yref="paper",
                showarrow=false,
                align="left",
                bgcolor="rgba(255,255,255,0.8)",
                bordercolor="rgba(128,128,128,0.5)",
                borderwidth=1
            )
        ]
    )

    return plot([trace, mean_line], layout)
end

"""
    create_autocall_timeline(autocall_periods::Vector{Int}, observation_days::Vector{Int},
                            title::String="Timeline de Autocalls")

Create timeline showing when autocalls occurred.
"""
function create_autocall_timeline(autocall_periods::Vector{Int}, observation_days::Vector{Int},
                                 title::String="Timeline de Autocalls")

    # Count autocalls by period
    period_counts = Dict{Int, Int}()
    total_paths = length(autocall_periods)

    for period in autocall_periods
        if period > 0  # 0 means no autocall (maturity)
            period_counts[period] = get(period_counts, period, 0) + 1
        end
    end

    # Calculate probabilities
    periods = sort(collect(keys(period_counts)))
    counts = [period_counts[p] for p in periods]
    probabilities = counts ./ total_paths * 100

    # Create bar chart
    trace = bar(
        x=periods,
        y=probabilities,
        name="Probabilidade de Autocall",
        marker=attr(
            color=FINANCIAL_COLORS.positive,
            opacity=0.8,
            line=attr(color="white", width=1)
        ),
        hovertemplate="<b>Semestre:</b> %{x}<br>" *
                     "<b>Probabilidade:</b> %{y:.1f}%<br>" *
                     "<b>Ocorrências:</b> %{customdata}<br>" *
                     "<extra></extra>",
        customdata=counts
    )

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        xaxis=attr(
            title="Semestre de Observação",
            tickmode="linear",
            tick0=1,
            dtick=1,
            gridcolor="rgba(128,128,128,0.2)"
        ),
        yaxis=attr(
            title="Probabilidade de Autocall (%)",
            tickformat=".1f",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)",
        hovermode="closest",
        showlegend=false
    )

    return plot([trace], layout)
end

"""
    create_margin_waterfall(principal::Float64, market_price::Float64, costs::Dict{String, Float64},
                           title::String="Decomposição da Margem")

Create waterfall chart showing margin decomposition.
"""
function create_margin_waterfall(principal::Float64, market_price::Float64, costs::Dict{String, Float64},
                                 title::String="Decomposição da Margem")

    # Calculate values
    gross_margin = principal - market_price
    net_margin = gross_margin - sum(values(costs))

    # Prepare data
    categories = ["Principal", "Custo Hedge", "Margem Bruta"]
    bar_values = [principal, -market_price, gross_margin]
    colors = [FINANCIAL_COLORS.neutral, FINANCIAL_COLORS.negative, FINANCIAL_COLORS.positive]

    # Add costs
    for (cost_name, cost_value) in costs
        push!(categories, cost_name)
        push!(bar_values, -cost_value)
        push!(colors, FINANCIAL_COLORS.negative)
    end

    # Add final margin
    push!(categories, "Margem Líquida")
    push!(bar_values, net_margin)
    push!(colors, net_margin >= 0 ? FINANCIAL_COLORS.positive : FINANCIAL_COLORS.negative)

    # Create waterfall
    trace = bar(
        x=categories,
        y=bar_values,
        name="Valores",
        marker=attr(color=colors, opacity=0.8),
        hovertemplate="<b>%{x}:</b><br>" *
                     "<b>Valor:</b> R\$ %{y:,.2f}<br>" *
                     "<extra></extra>"
    )

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        xaxis=attr(
            title="Componentes",
            tickangle=-45,
            gridcolor="rgba(128,128,128,0.2)"
        ),
        yaxis=attr(
            title="Valor (R\$)",
            tickformat=",.0f",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)",
        hovermode="closest",
        showlegend=false
    )

    return plot([trace], layout)
end

"""
    create_raroc_gauge(raroc::Float64, cost_of_capital::Float64=0.15,
                      title::String="RAROC vs Custo de Capital")

Create gauge chart for RAROC visualization.
"""
function create_raroc_gauge(raroc::Float64, cost_of_capital::Float64=0.15,
                           title::String="RAROC vs Custo de Capital")

    # Convert to percentage
    raroc_pct = raroc * 100
    cost_pct = cost_of_capital * 100

    # Determine color based on performance
    color = if raroc >= cost_of_capital * 1.5
        FINANCIAL_COLORS.positive
    elseif raroc >= cost_of_capital
        FINANCIAL_COLORS.highlight
    else
        FINANCIAL_COLORS.negative
    end

    # Create gauge
    trace = indicator(
        mode="gauge+number+delta",
        value=raroc_pct,
        delta=attr(reference=cost_pct, increasing=attr(color=FINANCIAL_COLORS.positive)),
        gauge=attr(
            axis=attr(range=[nothing, max(100, raroc_pct * 1.2)]),
            bar=attr(color=color),
            steps=[
                attr(range=[0, cost_pct], color="lightgray"),
                attr(range=[cost_pct, cost_pct * 1.5], color="gold"),
                attr(range=[cost_pct * 1.5, 100], color="lightgreen")
            ],
            threshold=attr(
                line=attr(color="red", width=4),
                thickness=0.75,
                value=cost_pct
            )
        ),
        number=attr(suffix="%"),
        title=attr(text="RAROC")
    )

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        paper_bgcolor="white",
        annotations=[
            attr(
                text=@sprintf("Custo de Capital: %.1f%%", cost_pct),
                x=0.5, y=0.1,
                xref="paper", yref="paper",
                showarrow=false,
                align="center",
                font=attr(size=14, color=FINANCIAL_COLORS.text_secondary)
            )
        ]
    )

    return plot([trace], layout)
end

"""
    create_sensitivity_heatmap(sensitivity_data::Matrix{Float64}, x_labels::Vector{String},
                              y_labels::Vector{String}, title::String="Análise de Sensibilidade")

Create heatmap for sensitivity analysis.
"""
function create_sensitivity_heatmap(sensitivity_data::Matrix{Float64}, x_labels::Vector{String},
                                   y_labels::Vector{String}, title::String="Análise de Sensibilidade")

    trace = heatmap(
        z=sensitivity_data,
        x=x_labels,
        y=y_labels,
        colorscale="RdYlGn",
        zmid=0,
        hovertemplate="<b>%{y}</b><br>" *
                     "<b>%{x}</b><br>" *
                     "<b>Impacto:</b> %{z:.2f}<br>" *
                     "<extra></extra>"
    )

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        xaxis=attr(title="Parâmetros", tickangle=-45),
        yaxis=attr(title="Cenários"),
        plot_bgcolor="white",
        paper_bgcolor="white"
    )

    return plot([trace], layout)
end

"""
    create_price_evolution_chart(paths_data::Matrix{Float64}, observation_days::Vector{Int},
                                asset_names::Vector{String}, title::String="Evolução de Preços")

Create line chart showing price evolution for multiple paths.
"""
function create_price_evolution_chart(paths_data::Matrix{Float64}, observation_days::Vector{Int},
                                     asset_names::Vector{String}, title::String="Evolução de Preços")

    traces = PlotlyJS.GenericTrace[]

    n_obs, n_assets, n_paths = size(paths_data)
    colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b"]

    # Show only first few paths to avoid clutter
    max_paths = min(10, n_paths)

    for path in 1:max_paths
        for asset in 1:n_assets
            trace = scatter(
                x=observation_days,
                y=paths_data[:, asset, path],
                mode="lines+markers",
                name="$(asset_names[asset]) - Path $path",
                line=attr(color=colors[asset], width=1, dash=path > 5 ? "dot" : "solid"),
                opacity=0.7,
                hovertemplate="<b>%{fullData.name}</b><br>" *
                             "<b>Dia:</b> %{x}<br>" *
                             "<b>Preço:</b> \$%{y:.2f}<br>" *
                             "<extra></extra>"
            )
            push!(traces, trace)
        end
    end

    layout = Layout(
        title=attr(
            text=title,
            font=attr(size=18, color=FINANCIAL_COLORS.text_primary)
        ),
        xaxis=attr(
            title="Dias",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        yaxis=attr(
            title="Preço (USD)",
            tickformat=",.0f",
            gridcolor="rgba(128,128,128,0.2)"
        ),
        plot_bgcolor="rgba(255, 255, 255, 0.95)",
        paper_bgcolor="rgba(255, 255, 255, 0.95)",
        hovermode="closest",
        showlegend=true
    )

    return plot(traces, layout)
end

# Export functions
export create_payoff_histogram, create_autocall_timeline, create_margin_waterfall,
       create_raroc_gauge, create_sensitivity_heatmap, create_price_evolution_chart
