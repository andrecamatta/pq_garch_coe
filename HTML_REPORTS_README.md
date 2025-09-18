# Sistema de Relatórios HTML Interativos - COE Autocall

## 🎯 Visão Geral

Sistema completo de relatórios HTML interativos e responsivos para análise de COE Autocall, desenvolvido com gráficos dinâmicos, dashboard profissional e design moderno.

## ✨ Funcionalidades Implementadas

### **1. Relatórios HTML Interativos**
- **Gráficos dinâmicos** com PlotlyJS (hover, zoom, pan)
- **Dashboard responsivo** com Bootstrap 5
- **Design profissional** com tema financeiro
- **Exportação automática** em HTML standalone

### **2. Tipos de Relatório**

#### **📊 Relatório de Simulação**
- Distribuição de payoffs (histograma interativo)
- Timeline de autocalls (gráfico de barras)
- Curva de sobrevivência
- Métricas principais em cards visuais
- Tabela de amostras detalhadas

#### **🏦 Relatório de Margem Bancária**
- Gauge RAROC vs Custo de Capital
- Decomposição de margem (waterfall chart)
- Análise competitiva
- Dashboard executivo
- Recomendações automáticas

### **3. Componentes Visuais**
- **Cards de métricas** com cores semânticas
- **Gráficos interativos** PlotlyJS
- **Tabelas responsivas** com ordenação
- **Badges de status** dinâmicos
- **Layout mobile-friendly**

## 🛠️ Arquitetura

### **Módulos Implementados**
```
src/
├── html_reports.jl           # Módulo base HTML
├── financial_plots.jl        # Gráficos financeiros
├── simulation_html_reports.jl # Relatório simulação
├── margin_html_reports.jl    # Relatório margem
└── html_templates/
    └── base_template.html    # Template responsivo
```

### **Dependências**
- **Obrigatórias:** Dates, Statistics, Printf
- **Opcionais:** PlotlyJS.jl, JSON3.jl, Colors.jl

## 📋 Como Usar

### **1. Relatório de Simulação HTML**
```julia
# Executar simulação
result = simulate_paths(models, dcc, specs, config; return_detailed=true)

# Exportar como HTML
export_simulation_results(result, specs, config; format=:html)
```

### **2. Relatório de Margem HTML**
```julia
# Calcular margem
margin_analysis = calculate_bank_margin(specs, config; offered_coupon=0.088)

# Exportar como HTML
output_dir = create_results_directory("margin_analysis")
export_bank_margin_results(margin_analysis, nothing, specs, config, output_dir; format=:html)
```

### **3. Ambos os Formatos**
```julia
# Gerar Markdown + HTML
export_simulation_results(result, specs, config; format=:both)
export_bank_margin_results(margin_analysis, nothing, specs, config, output_dir; format=:both)
```

## 🎨 Design e Estilo

### **Paleta de Cores Financeiras**
- **Verde (#28a745):** Margens positivas, autocalls
- **Vermelho (#dc3545):** Margens negativas, perdas
- **Azul (#007bff):** Métricas neutras, benchmarks
- **Dourado (#ffc107):** Destaques, KPIs principais

### **Layout Responsivo**
- **Desktop:** Layout completo com sidebar
- **Tablet:** Adaptação automática de colunas
- **Mobile:** Layout empilhado otimizado

### **Componentes Bootstrap**
- Cards com sombras e hover effects
- Navbar responsivo
- Sistema de grid flexível
- Tipografia otimizada

## 📊 Gráficos Disponíveis

### **Simulação**
1. **Histograma de Payoffs** - Distribuição interativa
2. **Timeline de Autocalls** - Probabilidades por semestre
3. **Curva de Sobrevivência** - Análise temporal

### **Margem Bancária**
1. **Gauge RAROC** - Performance vs custo capital
2. **Waterfall Chart** - Decomposição de margem
3. **Análise Competitiva** - Comparação de cupons

## 🔧 Configuração

### **Instalação de Dependências Opcionais**
```julia
using Pkg
Pkg.add(["PlotlyJS", "JSON3", "Colors"])
```

### **Verificação do Sistema**
```julia
# Teste básico (sem dependências)
julia test_html_basic.jl

# Teste completo (com PlotlyJS)
julia test_html_reports.jl
```

## 📁 Estrutura de Output

### **Arquivos Gerados**
```
results/nome_relatorio_YYYY-MM-DD_HH-MM-SS/
├── simulation_report.html     # Relatório HTML interativo
├── simulation_report.md       # Relatório Markdown tradicional
├── detailed_samples.csv       # Dados tabulares
├── payoff_distribution.csv    # Distribuição de payoffs
└── survival_probabilities.csv # Probabilidades de sobrevivência
```

### **Relatório de Margem**
```
results/margin_analysis_YYYY-MM-DD_HH-MM-SS/
├── margin_analysis.html       # Dashboard HTML interativo
├── bank_margin_report.md      # Relatório Markdown
├── bank_margin_analysis.csv   # Métricas detalhadas
└── margin_scenarios.csv       # Análise de cenários
```

## ⚙️ Funcionalidades Avançadas

### **1. Modo de Fallback**
- Sistema funciona **mesmo sem PlotlyJS**
- Degrada graciosamente para HTML básico
- Mantém toda funcionalidade de dados

### **2. Exportação e Impressão**
- **Botão de exportar** HTML completo
- **Modo de impressão** otimizado
- **Compatibilidade** com todos navegadores

### **3. Performance**
- **Lazy loading** de gráficos
- **Compressão** de dados JSON
- **Cache** de templates

## 🚀 Benefícios

### **Para Usuários**
- **Visualização superior** vs relatórios estáticos
- **Interatividade** com hover, zoom, filtros
- **Design profissional** para apresentações
- **Mobile-friendly** para análise em movimento

### **Para Desenvolvedores**
- **Modular e extensível**
- **Backwards compatible**
- **Fácil customização**
- **Documentação completa**

## 📈 Comparação: Antes vs Depois

| Aspecto | Markdown (Antes) | HTML (Depois) |
|---------|------------------|---------------|
| **Visualização** | Tabelas estáticas | Gráficos interativos |
| **Design** | Texto simples | Dashboard responsivo |
| **Interatividade** | Nenhuma | Hover, zoom, filtros |
| **Mobile** | Limitado | Totalmente responsivo |
| **Profissionalismo** | Básico | Apresentação executiva |
| **Análise** | Manual | Visual instantânea |

## 🔮 Próximos Passos

### **Melhorias Futuras**
- **Temas customizáveis** (claro/escuro)
- **Gráficos 3D** para análise avançada
- **Animações** em transições
- **Export PDF** direto do HTML
- **Compartilhamento** via link

### **Integrações**
- **Dashboard web** em tempo real
- **API REST** para dados
- **Notificações** automáticas
- **Backup** em nuvem

## 📞 Suporte

### **Troubleshooting**
- **Erro PlotlyJS:** `Pkg.add("PlotlyJS")`
- **Gráficos não aparecem:** Verificar JavaScript habilitado
- **Layout quebrado:** Atualizar navegador
- **Performance lenta:** Reduzir número de simulações

### **Logs e Debug**
- Mensagens detalhadas durante geração
- Fallback automático em caso de erro
- Validação de dependências

---

**🎉 Sistema de Relatórios HTML implementado com sucesso!**

*Transformando análise financeira com visualização interativa e design moderno.*