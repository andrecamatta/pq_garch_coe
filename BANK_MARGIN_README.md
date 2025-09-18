# Sistema de Análise de Margem Bancária - COE Autocall

## 🏦 Visão Geral

Este sistema adiciona capacidades abrangentes de análise de margem bancária ao COE Autocall Pricer, permitindo que bancos analisem a rentabilidade da oferta de cupons de até 8,8% semestral comparado ao valor justo calculado via Monte Carlo.

## 🚀 Funcionalidades Implementadas

### 1. **Análise de Margem Completa**
- Cálculo do cupom justo (que iguala preço ao principal)
- Comparação com cupom oferecido (8,8% semestral)
- Decomposição completa de margem bruta → líquida

### 2. **Análise de Custos Bancários**
- Custos operacionais (% do principal por ano)
- Buffer de risco regulatório
- Custo de capital (Basel III)
- Métricas RAROC (Risk-Adjusted Return on Capital)

### 3. **Análise de Cenários**
- Cenário base
- Cenário stress (+50% volatilidade)
- Cenário otimista (-30% volatilidade)
- VaR e Expected Shortfall da margem

### 4. **Análise de Sensibilidade**
- Sensibilidade à volatilidade dos ativos
- Sensibilidade à correlação entre ativos
- Sensibilidade às taxas de juros
- Análise de breakeven

### 5. **Análise Competitiva**
- Comparação com benchmarks de mercado (CDI + spread)
- Análise de diferentes níveis de cupom
- Avaliação de competitividade do produto

### 6. **Sistema de Relatórios**
- Relatórios executivos em Markdown
- Exportação completa em CSV
- Dashboards para diferentes stakeholders
- Documentação detalhada de metodologia

## 📁 Arquivos e Scripts

### Scripts Principais
- **`bank_margin_analysis.jl`** - Análise completa de margem bancária
- **`test_margin_simple.jl`** - Teste do sistema com dados mock
- **`find_fair_coupon.jl`** - Agora inclui análise de margem

### Arquivos de Sistema
- **`src/autocall_pricer.jl`** - Expandido com funções de margem
- **`src/simulation_export.jl`** - Sistema de exportação de margem

### Outputs Gerados
```
results/bank_margin_analysis_YYYY-MM-DD_HH-MM-SS/
├── bank_margin_analysis.csv      # Métricas detalhadas
├── bank_margin_report.md         # Relatório executivo
├── margin_scenarios.csv          # Análise de cenários
├── margin_sensitivity.csv        # Análise de sensibilidade
└── competitive_analysis.csv      # Comparação de cupons
```

## 🎯 Como Usar

### Análise Completa
```bash
julia bank_margin_analysis.jl
```

### Teste Rápido (sem API)
```bash
julia test_margin_simple.jl
```

### Análise de Cupom Justo + Margem
```bash
julia find_fair_coupon.jl
```

## 📊 Principais Métricas

### Métricas de Margem
- **Cupom Oferecido**: 8,8% semestral (máximo do produto)
- **Cupom Justo**: Calculado via Monte Carlo
- **Spread Bruto**: Diferença entre oferecido e justo
- **Margem Absoluta**: Diferença de preço em BRL
- **Margem Líquida**: Após custos operacionais e regulatórios

### Métricas de Risco-Retorno
- **RAROC**: Risk-Adjusted Return on Capital
- **VaR 95%**: Value at Risk da margem
- **Expected Shortfall**: Perda esperada em cenários extremos
- **Volatilidade da Margem**: Sensibilidade a fatores de risco

### Métricas Competitivas
- **Benchmark CDI + Spread**: Comparação com produtos similares
- **Cupom de Breakeven**: Ponto de margem zero
- **Avaliação de Competitividade**: Muito/Pouco/Competitivo

## 🔧 Configuração de Parâmetros

### Custos Bancários (customizáveis)
```julia
operational_cost_rate = 0.005    # 0,5% ao ano (custos operacionais)
risk_buffer_rate = 0.015         # 1,5% (buffer de risco)
capital_ratio = 0.12             # 12% (capital regulatório)
cost_of_capital = 0.15           # 15% (custo de capital)
```

### Cenários de Stress
```julia
scenarios = [:base, :stress, :optimistic]
vol_range = [-0.3, 0.0, 0.5]    # -30% a +50% volatilidade
corr_range = [-0.2, 0.0, 0.3]   # -20% a +30% correlação
rate_range = [-0.02, 0.0, 0.02] # -200bps a +200bps taxas
```

## 📈 Interpretação dos Resultados

### ✅ Margem Positiva
- Spread oferecido > cupom justo
- RAROC > custo de capital (15%)
- Produto rentável para o banco

### ⚠️ Margem Negativa
- Cupom oferecido muito alto
- Requer ajuste ou repricing
- Produto não rentável

### 🎯 Análise Competitiva
- **Muito Competitivo**: Cupom > CDI + 300bps
- **Competitivo**: Cupom > CDI + spread
- **Pouco Competitivo**: Cupom ≤ CDI + spread

## 🧪 Validação e Testes

### Sistema Testado e Validado
- ✅ Cálculo de cupom justo via bisection
- ✅ Decomposição completa de margem
- ✅ Análise de cenários múltiplos
- ✅ Sistema de exportação
- ✅ Análise competitiva
- ✅ Métricas de risco (VaR, RAROC)

### Casos de Teste
- Cupons extremos (2% a 15%)
- Cenários de stress de volatilidade
- Diferentes configurações de custo
- Exportação de relatórios

## 📋 Exemplo de Resultado

```
💼 RESUMO DE MARGEM (Cupom 8,8%):
  • Spread sobre justo: 1.2 p.p.
  • Margem bruta: R$ 450.00
  • Margem líquida: R$ 180.00
  • Margem %: 3.6% do principal
  • RAROC: 25.2%
  • Competitividade: Competitivo

✅ MARGEM POSITIVA: Produto rentável para o banco
```

## 🔮 Próximos Passos

### Melhorias Futuras
- Integração com sistemas de pricing bancário
- Análise de portfólio de produtos estruturados
- Métricas ESG e sustentabilidade
- Dashboard interativo em tempo real

---

**📞 Suporte**: Para dúvidas sobre o sistema de margem bancária, consulte a documentação técnica ou execute os scripts de teste.