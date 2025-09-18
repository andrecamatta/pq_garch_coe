# COE Autocall Tech - Sistema Completo de Análise

Sistema avançado de precificação e análise de Certificados de Operações Estruturadas (COE) do tipo Autocall com:
- **Precificação via DCC-GARCH Monte Carlo**
- **Análise de margem bancária completa**
- **Relatórios HTML interativos**
- **Dashboard financeiro responsivo**

## 🚀 Comando Único - Análise Completa

```bash
julia coe_analysis.jl
```

**Um comando faz tudo:**
- ✅ Carrega preços dos ativos (API Tiingo)
- ✅ Calibra modelos GARCH/DCC automaticamente
- ✅ Executa simulação Monte Carlo (10,000 paths)
- ✅ Calcula margem bancária (cupom 8.8% vs justo)
- ✅ Gera relatórios HTML interativos
- ✅ Gera relatórios Markdown tradicionais
- ✅ Organiza tudo em diretório timestamped

## 📊 Características do COE Autocall Tech

- **Ativos subjacentes**: AMD, Amazon (AMZN), Meta (META), TSMC (TSM)
- **Prazo**: 5 anos (1.260 dias úteis)
- **Observações**: Semestrais (10 observações a cada 126 dias)
- **Cupom**: 8.0% a 8.8% por semestre
- **Capital protegido** ao vencimento
- **Autocall**: Vence antecipadamente se todas as ações estiverem ≥ preço inicial
- **Principal**: R$ 10.000

## 📁 Estrutura do Projeto

```
pq_garch_coe/
├── coe_analysis.jl              # 🎯 COMANDO ÚNICO PRINCIPAL
├── src/                         # Módulos core
│   ├── autocall_pricer.jl        # Motor de precificação DCC-GARCH
│   ├── simulation_export.jl      # Export e relatórios
│   ├── html_reports.jl           # Sistema HTML interativo
│   ├── financial_plots.jl        # Gráficos financeiros PlotlyJS
│   ├── simulation_html_reports.jl # Relatórios simulação HTML
│   ├── margin_html_reports.jl     # Relatórios margem HTML
│   ├── html_templates/            # Templates responsivos
│   ├── tiingo_api.jl             # Interface com API Tiingo
│   ├── nelson_siegel_svensson.jl # Curva de juros brasileira
│   └── usd_curve.jl              # Curva Treasury USD
├── scripts/                     # Utilitários específicos
│   ├── bank_margin_analysis.jl   # Análise margem isolada
│   ├── find_fair_coupon.jl       # Busca cupom justo
│   ├── detailed_autocall_analysis.jl # Análise detalhada
│   └── payoff_distribution.jl     # Distribuição payoffs
├── test/                        # Testes organizados
│   ├── test_html_reports.jl      # Testes sistema HTML
│   ├── test_bank_margin.jl       # Testes margem bancária
│   └── ...
├── results/                     # Outputs automáticos
├── Project.toml                 # Dependências Julia
├── .env                         # Chave da API (não versionado)
└── HTML_REPORTS_README.md       # Documentação sistema HTML
```

## 🔧 Instalação

### 1. Instalar Julia
```bash
curl -fsSL https://install.julialang.org | sh
```

### 2. Clonar o Repositório
```bash
git clone https://github.com/andrecamatta/pq_garch_coe.git
cd pq_garch_coe
```

### 3. ⚠️ IMPORTANTE: Configurar API Tiingo
**O projeto precisa de uma chave API da Tiingo para buscar dados de mercado:**

1. **Obtenha uma chave gratuita em:** https://www.tiingo.com/
2. **Crie o arquivo `.env` na raiz do projeto:**
   ```bash
   echo "TIINGO_API_KEY=sua_chave_aqui" > .env
   ```

   Ou crie manualmente o arquivo `.env` com o conteúdo:
   ```
   TIINGO_API_KEY=sua_chave_da_tiingo_aqui
   ```

⚠️ **Sem esta configuração, o sistema não conseguirá baixar os preços dos ativos!**

### 4. Instalar Dependências Julia
```bash
julia -e "using Pkg; Pkg.instantiate()"
```

### 5. Dependências Opcionais (para relatórios HTML)
```julia
using Pkg
Pkg.add(["PlotlyJS", "JSON3", "Colors"])
```

## 📈 Outputs Gerados

### Estrutura de Resultados
```
results/coe_analysis_YYYY-MM-DD_HH-MM-SS/
├── 📊 simulation_report.html     # Relatório simulação interativo
├── 🏦 margin_analysis.html       # Dashboard margem bancária
├── 📋 simulation_report.md       # Relatório simulação markdown
├── 📋 bank_margin_report.md      # Relatório margem markdown
├── 📊 detailed_samples.csv       # Dados tabulares detalhados
├── 📈 payoff_distribution.csv    # Distribuição de payoffs
├── 🏦 bank_margin_analysis.csv   # Métricas de margem
└── 📊 survival_probabilities.csv # Probabilidades por semestre
```

### Relatórios HTML Interativos
- **Gráficos dinâmicos** (hover, zoom, pan) com PlotlyJS
- **Dashboard responsivo** com Bootstrap 5
- **Design profissional** para apresentações executivas
- **Mobile-friendly** para análise em movimento
- **Métricas visuais** com cores semânticas

### Gráficos Inclusos
**Simulação:**
- Histograma de payoffs interativo
- Timeline de autocalls por semestre
- Curva de sobrevivência
- Evolução de preços por path

**Margem Bancária:**
- Gauge RAROC vs custo de capital
- Decomposição de margem (waterfall chart)
- Análise competitiva
- Cenários de sensibilidade

## 🏦 Análise de Margem Bancária

O sistema calcula automaticamente:

### Métricas Principais
- **Cupom oferecido vs cupom justo**
- **Margem bruta e líquida**
- **RAROC (Risk-Adjusted Return on Capital)**
- **VaR e Expected Shortfall**
- **Análise competitiva**

### Custos Considerados
- **Custos operacionais**: 0.5% a.a.
- **Buffer de risco**: 1.5%
- **Capital regulatório**: 12%
- **Custo de capital**: 15% a.a.

### Dashboard Executivo
- Status visual (margem positiva/negativa)
- Recomendações automáticas
- Breakeven analysis
- Cenários de stress

## 🧮 Modelo Matemático

### DCC-GARCH com Medida Risco-Neutra

1. **GARCH(1,1) Univariado**:
   ```
   σ²ₜ = ω + α·ε²ₜ₋₁ + β·σ²ₜ₋₁
   ```
   - Distribuição t-Student com ν calibrado por ativo
   - Captura caudas pesadas dos retornos

2. **DCC (Dynamic Conditional Correlation)**:
   ```
   Qₜ = (1-a-b)·Q̄ + a·zₜ₋₁z'ₜ₋₁ + b·Qₜ₋₁
   Rₜ = diag(Qₜ)^(-1/2) · Qₜ · diag(Qₜ)^(-1/2)
   ```
   - Correlações dinâmicas entre ativos
   - Parâmetros (a,b) calibrados dos dados

3. **Simulação Risco-Neutra**:
   ```
   drift = r_USD(t)/252 - dividend_yield/252 - 0.5*σ²
   S(t+1) = S(t) * exp(drift + σ * ε_t)
   ```

4. **Numéraire USD**:
   ```
   FX_forward(T) = FX_spot * exp((r_BRL - r_USD) * T)
   PV_BRL = payoff_USD * exp(-r_USD*T) * FX_spot
   ```

## 🛠️ Scripts Específicos

### Análises Isoladas
```bash
# Margem bancária específica
julia scripts/bank_margin_analysis.jl

# Busca cupom justo
julia scripts/find_fair_coupon.jl

# Análise detalhada por semestre
julia scripts/detailed_autocall_analysis.jl

# Distribuição de payoffs
julia scripts/payoff_distribution.jl
```

### Testes do Sistema
```bash
# Teste sistema HTML completo
julia test/test_html_reports.jl

# Teste margem bancária
julia test/test_bank_margin.jl

# Teste simulação detalhada
julia test/test_detailed_simulation.jl
```

## ⚙️ Personalização

### Ajustar Parâmetros
```julia
# Em coe_analysis.jl ou nos scripts específicos:

# Principal e configuração
config = AutocallConfig(
    fill(0.08, 10),    # Cupom por semestre
    126,               # Dias entre observações
    1260,              # Prazo total
    10000.0,           # Principal
    0.10,              # Taxa livre de risco BRL
    nss_params,        # Curva BRL
    usd_curve,         # Curva USD
    5.2                # FX spot BRL/USD
)

# Margem bancária
margin_analysis = calculate_bank_margin(
    specs, config;
    offered_coupon=0.088,        # 8.8% oferecido
    operational_cost_rate=0.005, # 0.5% custos operacionais
    risk_buffer_rate=0.015,      # 1.5% buffer
    capital_ratio=0.12,          # 12% capital
    cost_of_capital=0.15         # 15% custo capital
)
```

### Formatos de Saída
```julia
# Apenas HTML
export_simulation_results(result, specs, config; format=:html)

# Apenas Markdown
export_simulation_results(result, specs, config; format=:markdown)

# Ambos os formatos
export_simulation_results(result, specs, config; format=:both)
```

## 📊 Exemplo de Saída

```
🏦 COE AUTOCALL - ANÁLISE COMPLETA
==================================

✅ Simulação concluída!
  📊 Preço médio: R$ 8,247.50
  📈 Desvio padrão: R$ 1,854.32
  🎯 Taxa de autocall: 67.4%

✅ Análise de margem concluída!
  💰 Margem líquida: R$ 1,133.39
  📊 RAROC: 80.6%
  🎯 Cupom justo: 12.5%
  ⚖️  Competitividade: Competitivo

📁 results/coe_analysis_2025-09-17_15-30-45/
├── 🌐 simulation_report.html
├── 🏦 margin_analysis.html
├── 📋 simulation_report.md
└── 📊 dados/ (CSVs)

🏆 ANÁLISE COE AUTOCALL FINALIZADA COM SUCESSO!
```

## 🔍 Troubleshooting

### Erro de API Key
```bash
# Verificar se o arquivo .env existe
ls -la .env

# Verificar conteúdo do .env
cat .env

# Se não existir, criar:
echo "TIINGO_API_KEY=sua_chave_aqui" > .env
```

### Dependências HTML
```julia
# Instalar dependências opcionais
using Pkg
Pkg.add(["PlotlyJS", "JSON3", "Colors"])
```

### Reinstalar Pacotes
```bash
julia -e "using Pkg; Pkg.instantiate(); Pkg.update()"
```

### Testes Básicos
```bash
# Teste sem dependências HTML
julia test/test_basic_output.jl

# Teste sistema completo
julia test/test_html_reports.jl
```

## 🆕 Novidades v2.0

### ✅ Sistema de Relatórios HTML
- **Gráficos interativos** PlotlyJS
- **Dashboard responsivo** Bootstrap 5
- **Design profissional** para apresentações
- **Fallback gracioso** sem dependências

### ✅ Análise de Margem Bancária
- **RAROC automático** vs custo de capital
- **Decomposição visual** de custos
- **Cenários de stress** e sensibilidade
- **Recomendações** automáticas

### ✅ Comando Único
- **Execução automática** completa
- **Zero configuração** manual
- **Output padronizado** e organizado
- **Arquivos organizados** por categoria

### ✅ Arquitetura Modular
- **Separação clara**: core/scripts/tests
- **Backwards compatible**
- **Extensível e customizável**
- **Documentação completa**

## ⚖️ Aviso Legal

Este é um modelo educacional para fins de estudo. Os resultados são baseados em simulações e dados históricos. Rentabilidade passada não garante resultados futuros. Consulte um profissional qualificado antes de tomar decisões de investimento.

---

**🎯 Para análise completa: `julia coe_analysis.jl`**

**📖 Para documentação HTML: [HTML_REPORTS_README.md](HTML_REPORTS_README.md)**