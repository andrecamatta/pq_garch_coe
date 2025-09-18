# COE Autocall Tech - Sistema de Precificação

Sistema de precificação de Certificados de Operações Estruturadas (COE) do tipo Autocall com:
- **Precificação via DCC-GARCH Monte Carlo**
- **Análise de margem bancária**
- **Relatórios HTML interativos**

## 🚀 Execução Principal

**Execute tudo com um comando:**

```bash
julia coe_analysis.jl
```

**Este comando faz:**
- ✅ Baixa preços dos ativos (API Tiingo)
- ✅ Calibra modelos GARCH/DCC automaticamente
- ✅ Executa simulação Monte Carlo (10.000 paths)
- ✅ Calcula margem bancária (cupom oferecido vs justo)
- ✅ Gera relatórios HTML e Markdown
- ✅ Organiza resultados por timestamp

## 📊 Características do COE

- **Ativos**: AMD, Amazon (AMZN), Meta (META), TSMC (TSM)
- **Prazo**: 5 anos (1.260 dias úteis)
- **Observações**: Semestrais (10 observações)
- **Cupom**: 8.8% por semestre
- **Capital protegido** ao vencimento
- **Autocall**: Vence antecipadamente se todas as ações ≥ preço inicial
- **Principal**: R$ 10.000

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
**O sistema precisa de uma chave API da Tiingo:**

1. **Obtenha chave gratuita:** https://www.tiingo.com/
2. **Crie arquivo `.env` na raiz:**
   ```bash
   echo "TIINGO_API_KEY=sua_chave_aqui" > .env
   ```

⚠️ **Sem esta configuração, o sistema não funciona!**

### 4. Instalar Dependências
```bash
julia -e "using Pkg; Pkg.instantiate()"
```

### 5. Executar
```bash
julia coe_analysis.jl
```

## 📈 Outputs Gerados

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

### Relatórios HTML
- **Gráficos dinâmicos** (hover, zoom, pan) com PlotlyJS
- **Dashboard responsivo** com Bootstrap 5
- **Design profissional** para apresentações
- **Mobile-friendly**

## 🏦 Análise de Margem Bancária

O sistema calcula automaticamente:

### Métricas Principais
- **Cupom oferecido vs cupom justo**
- **Margem bruta e líquida**
- **RAROC (Risk-Adjusted Return on Capital)**
- **VaR e Expected Shortfall**

### Custos Considerados
- **Custos operacionais**: 0.5% a.a.
- **Buffer de risco**: 1.5%
- **Capital regulatório**: 12%
- **Custo de capital**: 15% a.a.

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

## 📁 Estrutura do Projeto

```
pq_garch_coe/
├── coe_analysis.jl              # 🎯 ARQUIVO PRINCIPAL
├── src/                         # Módulos core
│   ├── autocall_pricer.jl       # Motor de precificação
│   ├── html_reports.jl          # Sistema HTML
│   ├── tiingo_api.jl            # Interface API
│   └── ...
├── scripts/                     # Utilitários
├── test/                        # Testes
├── results/                     # Outputs
├── Project.toml                 # Dependências
└── .env                         # Chave API (criar)
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

📁 results/coe_analysis_2025-09-17_15-30-45/
├── 🌐 simulation_report.html
├── 🏦 margin_analysis.html
└── 📊 dados/ (CSVs)

🏆 ANÁLISE COE AUTOCALL FINALIZADA COM SUCESSO!
```

## 🔍 Troubleshooting

### Erro de API Key
```bash
# Verificar se .env existe
ls -la .env

# Criar se necessário
echo "TIINGO_API_KEY=sua_chave_aqui" > .env
```

### Reinstalar Pacotes
```bash
julia -e "using Pkg; Pkg.instantiate(); Pkg.update()"
```

## ⚖️ Aviso Legal

Modelo educacional para fins de estudo. Resultados baseados em simulações e dados históricos. Rentabilidade passada não garante resultados futuros. Consulte um profissional qualificado antes de investir.

---

**🎯 Para análise completa: `julia coe_analysis.jl`**