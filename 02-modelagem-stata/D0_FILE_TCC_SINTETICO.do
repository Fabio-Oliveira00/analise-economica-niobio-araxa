*As etapas 1 ao 4 são padrão para todos os controles sintéticos, então cada teste depois do primeiro começará na etapa 5.

* ---------------------------------------------------------
* 1. CONFIGURAÇÃO INICIAL DO AMBIENTE
* ---------------------------------------------------------

* Limpa a memória de dados 
clear all

* Desativa a pausa automática do Stata (o "--more--") para rodar tudo direto
set more off

* PREPARAÇÃO DA MEMÓRIA
set matsize 1000
*set memory 500m

* Define o caminho da pasta onde está o seu novo arquivo
cd "C:\Users\fabio\TCC\CONSOLIDADO"

* ---------------------------------------------------------
* 2. CARREGAMENTO DA BASE DE DADOS
* ---------------------------------------------------------

* Carrega o arquivo .dta (formato nativo do Stata)
use "PAINEL_MINAS_SAUDE_FINAL.dta", clear

* Converte a variável id_ano de texto (str) para número (int/float)
destring id_ano, replace

* Mostra um resumo das variáveis para conferirmos os tipos (storage type)
describe

* ---------------------------------------------------------
* 3. DEFINIÇÃO DA ESTRUTURA DE PAINEL (PANEL DATA)
* ---------------------------------------------------------

* Garante que o ID e o ANO sejam numéricos
destring id_municipio_6, replace force
destring id_ano, replace force

* Define o painel
xtset id_municipio_6 id_ano

* ---------------------------------------------------------
* 4. PREPARAÇÃO PARA O CONTROLE SINTÉTICO
* ---------------------------------------------------------

* Instala o pacote synth
ssc install synth, replace

* Verifica os dados de Araxá para definir o ano de início do Controle Sintético
list id_ano id_municipio_6 ind_pib_pc_real_mil bruto_emp_formal_total ///
     if id_municipio_6 == 310400 & id_ano <= 2006
	 
* ---------------------------------------------------------
* 5. EXECUÇÃO DO CONTROLE SINTÉTICO - PIB PC
* ---------------------------------------------------------

* 1. PREPARAÇÃO DA BASE
clear all 
set matsize 1000
set memory 500m  

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* 2. CRIAÇÃO DE VARIÁVEIS
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_populacao          pop
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
keep id_municipio_6 id_ano pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE DADOS
local preditoras pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. RECONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_pib_v2.dta 

* 6. O COMANDO SYNTH (PADRÃO)
* Usamos a estratégia das MÉDIAS (2002-2004).

synth pib_pc ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      vab_serv(2002(1)2004) ///
      emp_min(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_pib_v2.dta)

* ---------------------------------------------------------
* 6. RESULTADOS: IDENTIFICANDO OS DOADORES (CORRIGIDO V2)
* ---------------------------------------------------------

* PASSO A: CRIAR UM DICIONÁRIO DE NOMES ÚNICOS
use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
keep id_municipio_6 id_nome_municipio
duplicates drop id_municipio_6, force
rename id_municipio_6 _Co_Number
save "dicionario_nomes_temp.dta", replace

* ---------------------------------------------------------

* PASSO B: CRUZAR COM OS RESULTADOS
use resultado_pib_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* ---------------------------------------------------------

* PASSO C: VER A TABELA DE DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* ---------------------------------------------------------

* PASSO D: O GRÁFICO DE IMPACTO
sort _time

twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto da Mineração no PIB per Capita") ///
       subtitle("Araxá vs. Controle Sintético (2002-2021)") ///
       xtitle("Ano") ytitle("PIB per Capita (Mil R$)") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria.")
	   
* ============================================================================================================================
* =========================================================
* BLOCO 2: ANÁLISE DO VAB DA INDÚSTRIA
* =========================================================

* ---------------------------------------------------------
* 5B. EXECUÇÃO DO CONTROLE SINTÉTICO (VAB INDÚSTRIA)
* ---------------------------------------------------------

* 1. RESET TOTAL (Garante que a memória do PIB não atrapalhe)
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros Padrão
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* 2. CRIAÇÃO DE VARIÁVEIS
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

* Renomear (Mesmos nomes curtos de sempre)
rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_populacao          pop
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
* Mantemos as mesmas variáveis, pois elas trocam de lugar na fórmula
keep id_municipio_6 id_ano pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE DADOS (Limpeza de missing values)
local preditoras pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min
foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. CONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_vab_v2.dta 

* 6. COMANDO SYNTH (ALVO: VAB INDÚSTRIA)
* Mudança: vab_ind é a primeira variável (resultado).
* Mudança: pib_pc entrou como preditora (2002-2004).
* Usamos a MÉDIA (2002-2004) para garantir que ele busque cidades industriais.
* Usamos o ANO 2004 (vab_ind(2004)) separadamente. 
* Isso força o gráfico a "colar" no último ano antes da intervenção, melhorando o visual sem destruir a estrutura das outras variáveis.

synth vab_ind ///
      vab_ind(2002(1)2004) ///
      vab_ind(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      vab_serv(2002(1)2004) ///
      emp_min(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_vab_v2.dta)
	
* ---------------------------------------------------------
* 6B. RESULTADOS DO VAB INDÚSTRIA
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES (Usamos o dicionário que já criamos lá em cima)
use resultado_vab_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES DO VAB
* (Quem são as cidades industriais parecidas com Araxá?)
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto da Mineração na Industrialização") ///
       subtitle("VAB Indústria (% do Total) - 2002-2021") ///
       xtitle("Ano") ytitle("Participação da Indústria (%)") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria.")

* ============================================================================================================================	   
* =========================================================
* BLOCO 3: ANÁLISE DO VAB DE SERVIÇOS
* =========================================================

* ---------------------------------------------------------
* 5C. EXECUÇÃO DO CONTROLE SINTÉTICO (VAB SERVIÇOS)
* ---------------------------------------------------------

* 1. RESET TOTAL
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros Padrão
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* 2. CRIAÇÃO DE VARIÁVEIS
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

* Renomear (Mesmos nomes curtos)
rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_populacao          pop
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
keep id_municipio_6 id_ano pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE DADOS
local preditoras pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min
foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. CONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_serv_v2.dta 

* 6. COMANDO SYNTH (ALVO: VAB SERVIÇOS)
* Estratégia da Âncora aplicada aqui também.

synth vab_serv ///
      vab_serv(2002(1)2004) ///
      vab_serv(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      emp_min(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_serv_v2.dta)

* ---------------------------------------------------------
* 6C. RESULTADOS DO VAB SERVIÇOS
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES
use resultado_serv_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto da Mineração nos Serviços") ///
       subtitle("VAB Serviços (% do Total) - 2002-2021") ///
       xtitle("Ano") ytitle("Participação dos Serviços (%)") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria.")

* ============================================================================================================================	 
* =========================================================
* BLOCO 4: ANÁLISE DA POPULAÇÃO (COM CORREÇÃO DE 2007)
* =========================================================

* ---------------------------------------------------------
* 5D. EXECUÇÃO DO CONTROLE SINTÉTICO (POPULAÇÃO)
* ---------------------------------------------------------

* 1. RESET TOTAL
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros Padrão
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* ---------------------------------------------------------
* PASSO EXTRA: CORRIGIR O BURACO DE 2007
* ---------------------------------------------------------
* A planilha base não possue dados para 2007, então vamos preencher esse dado com a média entre o ano antes e o ano depois
* 1. Define o painel para o Stata entender a sequência de tempo
xtset id_municipio_6 id_ano

* 2. Preenche os anos que estão faltando (cria linhas vazias para 2007)
tsfill

* 3. Preenche os dados de População em 2007 (Média entre 2006 e 2008)
* (Fazemos isso renomeando antes para facilitar)
rename bruto_populacao pop

* O comando ipolate cria uma nova variável 'pop_f' preenchida
by id_municipio_6: ipolate pop id_ano, gen(pop_corrigida)

* Substituímos a variável original pela corrigida
drop pop
rename pop_corrigida pop

* ---------------------------------------------------------

* 2. CRIAÇÃO DE VARIÁVEIS (REFEITA PARA AS OUTRAS)
* Atenção: Como usamos tsfill, as outras variáveis ficaram vazias em 2007.
* Precisamos interpolar elas também se formos usá-las como preditoras (controles).
* Para simplificar e evitar erros, vamos interpolar apenas as essenciais ou confiar que o synth vai ignorar 2007 nas médias das preditoras.

* Vamos recriar as variáveis relativas (o tsfill pode ter deixado buracos)
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

* Renomear (as que ainda não foram renomeadas)
rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
keep id_municipio_6 id_ano pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE DADOS
* Importante: Não vamos filtrar por 2007 aqui para não deletar o que acabamos de criar.
local preditoras pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min
foreach var of local preditoras {
    gen temp_miss = 0
    * Verificamos apenas o período de ajuste original (2002-2004)
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. CONFIGURAÇÃO FINAL
xtset id_municipio_6 id_ano
capture erase resultado_pop_v2.dta 

* 6. COMANDO SYNTH (ALVO: POPULAÇÃO)

synth pop ///
      pop(2002(1)2004) ///
      pop(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      vab_serv(2002(1)2004) ///
      emp_min(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_pop_v2.dta)

* ---------------------------------------------------------
* 6D. RESULTADOS DA POPULAÇÃO
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES
use resultado_pop_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto da Mineração na População") ///
       subtitle("População Residente Total (2002-2021)") ///
       xtitle("Ano") ytitle("Número de Habitantes") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria. *Ano de 2007 interpolado.")
	   
* ============================================================================================================================
* =========================================================
* BLOCO 5: ANÁLISE DO EMPREGO FORMAL TOTAL
* =========================================================

* ---------------------------------------------------------
* 5E. EXECUÇÃO DO CONTROLE SINTÉTICO (EMPREGO TOTAL)
* ---------------------------------------------------------

* 1. RESET TOTAL
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros Padrão
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* ---------------------------------------------------------
* PASSO EXTRA: CORRIGIR O BURACO DE 2007 (EMPREGO)
* ---------------------------------------------------------
xtset id_municipio_6 id_ano
tsfill

* Renomeamos para facilitar a interpolação
rename bruto_emp_formal_total emp_tot

* Interpolar: preenche 2007 com a média entre 2006 e 2008
by id_municipio_6: ipolate emp_tot id_ano, gen(emp_tot_corrigida)
drop emp_tot
rename emp_tot_corrigida emp_tot

* ---------------------------------------------------------

* 2. CRIAÇÃO DE VARIÁVEIS (REFEITA APÓS TSFILL)
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

* Renomear as outras
rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_populacao          pop
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
keep id_municipio_6 id_ano pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE DADOS
local preditoras pib_pc mort_inf pop emp_tot vab_ind vab_serv emp_min
foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. CONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_emp_v2.dta 

* 6. COMANDO SYNTH (ALVO: EMPREGO TOTAL)
* Estratégia da Âncora: Média + Ano 2004.

synth emp_tot ///
      emp_tot(2002(1)2004) ///
      emp_tot(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      vab_serv(2002(1)2004) ///
      emp_min(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_emp_v2.dta)

* ---------------------------------------------------------
* 6E. RESULTADOS DO EMPREGO TOTAL
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES
use resultado_emp_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto da Mineração no Emprego Total") ///
       subtitle("Estoque de Vínculos Formais (2002-2021)") ///
       xtitle("Ano") ytitle("Número de Vínculos") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria. *Ano de 2007 interpolado.")
	   
* ============================================================================================================================	   
* =========================================================
* BLOCO 6: ANÁLISE DA MINERAÇÃO NO EMPREGO
* =========================================================

* ---------------------------------------------------------
* 5F. EXECUÇÃO DO CONTROLE SINTÉTICO (MINERAÇÃO %)
* ---------------------------------------------------------

* 1. RESET
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* ---------------------------------------------------------
* 2. CRIAÇÃO E CORREÇÃO DE VARIÁVEIS (O PULO DO GATO)
* ---------------------------------------------------------

* A) Recalcular a % de Mineração (Para corrigir o erro da planilha)
* Fórmula: (Emprego Mineração / Emprego Total) * 100
gen emp_min = (bruto_emp_mineracao / bruto_emp_formal_total) * 100

* B) Criar VAB Serviços (que também é calculado)
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

* C) Renomear as outras (Controles)
rename ind_pib_pc_real_mil      pib_pc
rename ind_mortalidade_infantil mort_inf
rename bruto_populacao          pop
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
* Mantemos a nova 'emp_min' que acabamos de calcular
keep id_municipio_6 id_ano emp_min pib_pc mort_inf pop emp_tot vab_ind vab_serv

* 4. FAXINA DE DADOS
* Importante: Cidades com 0 emprego na mineração são comuns e NÃO são erro.
* Só deletamos se o dado for "missing" (ponto).
local preditoras emp_min pib_pc mort_inf pop emp_tot vab_ind vab_serv
foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 5. CONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_min_v2.dta 

* 6. COMANDO SYNTH (ALVO: EMP_MIN %)
* Estratégia da Âncora: Média + Ano 2004.

synth emp_min ///
      emp_min(2002(1)2004) ///
      emp_min(2004) ///
      pib_pc(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      pop(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_min_v2.dta)

* ---------------------------------------------------------
* 6F. RESULTADOS DA MINERAÇÃO
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES
use resultado_min_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto na Estrutura de Trabalho: Mineração") ///
       subtitle("Participação da Mineração no Emprego Total (%)") ///
       xtitle("Ano") ytitle("% do Emprego Total") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria. Dados recalculados.")

* ============================================================================================================================	   
* =========================================================
* BLOCO 7: ANÁLISE DA MORTALIDADE INFANTIL (VARREDURA TOTAL)
* =========================================================

* ---------------------------------------------------------
* 1G. EXECUÇÃO DO CONTROLE SINTÉTICO (MORTALIDADE INFANTIL)
* ---------------------------------------------------------

* 1. RESET TOTAL
clear all 
set matsize 1000
set memory 500m

use "PAINEL_MINAS_SAUDE_FINAL.dta", clear
destring id_municipio_6, replace force
destring id_ano, replace force

* Filtros Padrão
keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

* ---------------------------------------------------------
* 2G: TENTAR SALVAR DADOS (INTERPOLAÇÃO)
* ---------------------------------------------------------
xtset id_municipio_6 id_ano
tsfill

rename ind_mortalidade_infantil mort_inf

* Interpolar para tentar tapar buracos pequenos
by id_municipio_6: ipolate mort_inf id_ano, gen(mort_inf_corrigida)
drop mort_inf
rename mort_inf_corrigida mort_inf

* ---------------------------------------------------------

* 2. CRIAÇÃO E RENOMEAÇÃO
gen ind_vab_serv = (bruto_vab_servicos / bruto_vab_total) * 100

rename ind_pib_pc_real_mil      pib_pc
rename bruto_populacao          pop
rename bruto_emp_formal_total   emp_tot
rename ind_part_vab_industria   vab_ind
rename ind_part_emp_mineracao   emp_min
rename ind_vab_serv             vab_serv

* 3. DIETA DE DADOS
keep id_municipio_6 id_ano mort_inf pib_pc pop emp_tot vab_ind vab_serv emp_min

* 4. FAXINA DE PREDITORAS (PERÍODO PRÉ)
local preditoras pib_pc pop emp_tot vab_ind
foreach var of local preditoras {
    gen temp_miss = 0
    replace temp_miss = 1 if missing(`var') & id_ano >= 2002 & id_ano <= 2004
    bysort id_municipio_6: egen temp_drop = max(temp_miss)
    drop if temp_drop == 1 & id_municipio_6 != 310400
    drop temp_miss temp_drop
}

* 4B. VARREDURA TOTAL DA MORTALIDADE
* Verifica se existe QUALQUER buraco na variável alvo entre 2002 e 2021.
* Se faltar dado em 2012, 2015 ou qualquer ano, a cidade sai.
gen erro_total = 0
replace erro_total = 1 if missing(mort_inf) & id_ano >= 2002 & id_ano <= 2021
bysort id_municipio_6: egen drop_city_total = max(erro_total)
drop if drop_city_total == 1 & id_municipio_6 != 310400
drop erro_total drop_city_total

* 5. CONFIGURAÇÃO
xtset id_municipio_6 id_ano
capture erase resultado_mort_v2.dta 

* 6. COMANDO SYNTH
synth mort_inf ///
      mort_inf(2002(1)2004) ///
      mort_inf(2004) ///
      pib_pc(2002(1)2004) ///
      pop(2002(1)2004) ///
      emp_tot(2002(1)2004) ///
      vab_ind(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      keep(resultado_mort_v2.dta)

* ---------------------------------------------------------
* 3G. RESULTADOS DA MORTALIDADE INFANTIL
* ---------------------------------------------------------

* PASSO A: CRUZAR NOMES
use resultado_mort_v2.dta, clear
merge m:1 _Co_Number using "dicionario_nomes_temp.dta"
keep if _merge == 3
drop _merge

* PASSO B: VER OS DOADORES
gsort -_W_Weight 
list id_nome_municipio _Co_Number _W_Weight if _W_Weight > 0.001 & _Co_Number != 310400

* PASSO C: GRÁFICO
sort _time
twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)) ///
       , legend(label(1 "Araxá (Real)") label(2 "Araxá Sintético")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       title("Impacto Social: Mortalidade Infantil") ///
       subtitle("Óbitos de menores de 1 ano por mil nascidos vivos (2002-2021)") ///
       xtitle("Ano") ytitle("Taxa de Mortalidade Infantil") ///
       xlabel(2002(2)2021) ///
       note("Fonte: Elaboração própria. *Dados interpolados.")
	   

* ============================================================================================================================
*	LENDO O ARQUIVO NOVO COM AS VARIÁVEIS DE SAÚDE

clear

* 1. Usar o comando antigo para ler CSV
insheet using "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.csv", clear

* 2. Verificar se carregou
describe

* 3. Salvar como .dta (Agora sim no formato correto)
save "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", replace


* ============================================================================================================================
* =========================================================
* BLOCO 8: BAIXO PESO (AMOSTRA LEVE - 40 CIDADES)
* =========================================================

* 1. PREPARAÇÃO
clear all
set matsize 1000
set memory 500m

use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear

destring id_municipio_6, replace force
destring id_ano, replace force

keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

xtset id_municipio_6 id_ano
tsfill

* 2. TRATAMENTO
rename ind_baixo_peso_pct       bx_peso
rename ind_pib_pc_real_mil      pib_pc
rename bruto_populacao          pop
rename ind_mortalidade_infantil mort_inf

foreach var in bx_peso pib_pc pop mort_inf {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 3. FILTRO + SORTEIO (40 CIDADES)
* ---------------------------------------------------------
* Passo A: Filtro de população (> 5.000)
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

* Passo B: SORTEIO DE 40
* 40 é o "número mágico" que costuma rodar em qualquer PC
preserve
    keep id_municipio_6
    duplicates drop
    gen is_araxa = (id_municipio_6 == 310400)
    
    set seed 999
    
    * SORTEANDO APENAS 40
    sample 40 if is_araxa == 0, count
    
    save "lista_cidades_40.dta", replace
restore

merge m:1 id_municipio_6 using "lista_cidades_40.dta"
keep if _merge == 3
drop _merge

* Verifica total (Deve ser ~41)
count if id_ano == 2002

* ---------------------------------------------------------
* 4. RODAR O SYNTH (COM NESTED)
* ---------------------------------------------------------
synth bx_peso ///
      bx_peso(2002(1)2004) ///
      bx_peso(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      figure nested keep(res_bxpeso.dta) replace

* ---------------------------------------------------------
* 5. VISUALIZAÇÃO
* ---------------------------------------------------------
use res_bxpeso.dta, clear

twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)), ///
       xline(2005, lpattern(dot)) ///
       title("Impacto no Baixo Peso ao Nascer (%)") ///
       subtitle("Araxá vs Controle Sintético (Amostra 40)") ///
       legend(label(1 "Araxá Real") label(2 "Araxá Sintético")) ///
       ytitle("% Nascidos Baixo Peso") xtitle("Ano")

* ============================================================================================================================

* =========================================================
* BLOCO 9: INTERNAÇÕES RESPIRATÓRIAS (AMOSTRA 50)
* =========================================================

* 1. PREPARAÇÃO
clear all
set matsize 2000       // Aumentei o matsize para garantir
set memory 800m        // Alocação inicial

use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear

destring id_municipio_6, replace force
destring id_ano, replace force

keep if id_uf == "MG"
drop if id_ano < 2002
drop if id_ano > 2021

xtset id_municipio_6 id_ano
tsfill

* 2. TRATAMENTO DE VARIÁVEIS
rename ind_internacoes_resp_por_mil tx_resp
rename ind_pib_pc_real_mil          pib_pc
rename bruto_populacao              pop
rename ind_mortalidade_infantil     mort_inf

foreach var in tx_resp pib_pc pop mort_inf {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 3. FILTRO + SORTEIO (50 CIDADES)
* ---------------------------------------------------------
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

preserve
    keep id_municipio_6
    duplicates drop
    gen is_araxa = (id_municipio_6 == 310400)
    
    set seed 999
    
    * TENTANDO COM 80 CIDADES
    * Se der erro de memória r(909), mude este número para 40.
    sample 50 if is_araxa == 0, count
    
    save "lista_cidades_resp_80.dta", replace
restore

merge m:1 id_municipio_6 using "lista_cidades_resp_80.dta"
keep if _merge == 3
drop _merge

* ---------------------------------------------------------
* 4. RODAR O SYNTH (COM NESTED)
* ---------------------------------------------------------
synth tx_resp ///
      tx_resp(2002(1)2004) ///
      tx_resp(2004) ///
      pib_pc(2002(1)2004) ///
      mort_inf(2002(1)2004) ///
      pop(2002(1)2004) ///
      , trunit(310400) trperiod(2005) ///
      figure nested keep(res_resp.dta) replace

* ---------------------------------------------------------
* 5. VISUALIZAÇÃO
* ---------------------------------------------------------
use res_resp.dta, clear

twoway (line _Y_treated _time, lcolor(blue) lwidth(thick)) ///
       (line _Y_synthetic _time, lcolor(red) lpattern(dash)), ///
       xline(2005, lpattern(dot)) ///
       title("Internações Respiratórias (por mil hab)") ///
       subtitle("Araxá vs Controle Sintético (Amostra 80)") ///
       legend(label(1 "Araxá Real") label(2 "Araxá Sintético")) ///
       ytitle("Taxa de Internação (por mil)") xtitle("Ano")


* ============================================================================================================================	   
* =========================================================
* BLOCO 10-PIB: PLACEBO NO ESPAÇO (TESTE DO PIB)
* =========================================================

clear all
set matsize 1000
set memory 500m

* 1. PREPARAÇÃO DA BASE
use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear
destring id_municipio_6 id_ano, replace force
keep if id_uf == "MG"
drop if id_ano < 2002 | id_ano > 2021
xtset id_municipio_6 id_ano
tsfill

* --- VARIÁVEL DE INTERESSE: PIB PER CAPITA ---
rename ind_pib_pc_real_mil      variavel_interesse

* --- PREDITORES ---
rename bruto_populacao          pop
rename ind_mortalidade_infantil mort_inf
rename ind_baixo_peso_pct       bx_peso 

* Interpolação
foreach var in variavel_interesse pop mort_inf bx_peso {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 2. DEFINIR O "POOL" DO PLACEBO (SORTEIO INTELIGENTE)
* Filtro: Cidades > 5.000 hab (Para comparar bananas com bananas)
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

* --- SORTEIO SEGURO (Araxá + 39 cidades) ---
preserve
    keep id_municipio_6
    duplicates drop
    
    set seed 12345
    gen sorteio = runiform()
    
    * Garante Araxá no topo (sorteio negativo)
    replace sorteio = -1 if id_municipio_6 == 310400
    
    sort sorteio
    keep in 1/40  // Mantemos 40 para ser rápido
    
    save "lista_placebos_pib.dta", replace
restore
* -------------------------------------------

merge m:1 id_municipio_6 using "lista_placebos_pib.dta"
keep if _merge == 3
drop _merge

save "base_placebo_pib.dta", replace

* 3. O LOOP DO PLACEBO (SEM NESTED)
postfile buffer double id_cidade ano gap using "resultados_placebo_pib.dta", replace

levelsof id_municipio_6, local(lista_cidades)

foreach cidade of local lista_cidades {
    
    noisily display "Rodando PIB para cidade: `cidade'..."
    
    use "base_placebo_pib.dta", clear
    
    if `cidade' == 310400 {
        local capture_opt "" 
    }
    else {
        local capture_opt "capture"
    }
    
    * SYNTH DO PIB (Sem nested para velocidade)
    `capture_opt' synth variavel_interesse ///
          variavel_interesse(2002(1)2004) ///
          variavel_interesse(2004) ///
          mort_inf(2002(1)2004) ///
          bx_peso(2002(1)2004) ///
          pop(2002(1)2004) ///
          , trunit(`cidade') trperiod(2005) ///
          keep(res_temp.dta) replace
          
    if _rc == 0 {
        use res_temp.dta, clear
        gen gap = _Y_treated - _Y_synthetic
        gen double id_cidade = `cidade'
        
        local N = _N
        forvalues i = 1/`N' {
            local ano_val = _time[`i']
            local gap_val = gap[`i']
            post buffer (`cidade') (`ano_val') (`gap_val')
        }
    }
}
postclose buffer

* 4. CALCULAR MSPE E PLOTAR
use "resultados_placebo_pib.dta", clear

gen gap_sq = gap^2
bysort id_cidade: egen mspe_pre = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_final = max(mspe_pre)

* Pega o MSPE de Araxá
sum mspe_final if id_cidade == 310400
local mspe_araxa = r(mean)

if `mspe_araxa' == . {
    display as error "ERRO CRÍTICO: Araxá não rodou!"
    exit
}

* Remove cidades com ajuste ruim (> 20x erro de Araxá)
gen razao_mspe = mspe_final / `mspe_araxa'
drop if razao_mspe > 20 & id_cidade != 310400

* 5. O GRÁFICO FINAL (A PROVA DOS 9)
gen is_araxa = (id_cidade == 310400)
sort id_cidade ano 

twoway (line gap ano if is_araxa == 0, lcolor(gs12) lwidth(thin) connect(L)) ///
       (line gap ano if is_araxa == 1, lcolor(red) lwidth(thick) connect(L)) ///
       , legend(order(2 "Araxá" 1 "Placebos (Outras Cidades)")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       yline(0, lpattern(solid) lcolor(black)) ///
       title("Teste de Placebo no Espaço: PIB per Capita") ///
       subtitle("Araxá vs Outras Cidades Mineiras") ///
       xtitle("Ano") ytitle("Gap (Real - Sintético) em Mil R$") ///
       note("Nota: Placebos com MSPE pré-intervenção > 20x Araxá foram removidos.")
	   
* ============================================================================================================================	   
	   
* =========================================================
* BLOCO 10-MORT: PLACEBO NO ESPAÇO (MORTALIDADE INFANTIL)
* =========================================================

clear all
set matsize 1000
set memory 500m

* 1. PREPARAÇÃO DA BASE
use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear
destring id_municipio_6 id_ano, replace force
keep if id_uf == "MG"
drop if id_ano < 2002 | id_ano > 2021
xtset id_municipio_6 id_ano
tsfill

* --- VARIÁVEL DE INTERESSE: MORTALIDADE INFANTIL ---
rename ind_mortalidade_infantil variavel_interesse

* --- PREDITORES ---
rename ind_pib_pc_real_mil      pib_pc
rename bruto_populacao          pop
rename ind_baixo_peso_pct       bx_peso 

* Interpolação (Essencial para séries de saúde)
foreach var in variavel_interesse pib_pc pop bx_peso {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 2. DEFINIR O "POOL" DO PLACEBO (SORTEIO INTELIGENTE)
* Filtro: Cidades > 5.000 hab
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

* --- SORTEIO SEGURO (Araxá + 39 cidades) ---
preserve
    keep id_municipio_6
    duplicates drop
    
    set seed 12345
    gen sorteio = runiform()
    
    * Garante Araxá no topo
    replace sorteio = -1 if id_municipio_6 == 310400
    
    sort sorteio
    keep in 1/40
    
    save "lista_placebos_mort.dta", replace
restore
* -------------------------------------------

merge m:1 id_municipio_6 using "lista_placebos_mort.dta"
keep if _merge == 3
drop _merge

save "base_placebo_mort.dta", replace

* 3. O LOOP DO PLACEBO (SEM NESTED PARA RAPIDEZ)
postfile buffer double id_cidade ano gap using "resultados_placebo_mort.dta", replace

levelsof id_municipio_6, local(lista_cidades)

foreach cidade of local lista_cidades {
    
    noisily display "Rodando Mortalidade para cidade: `cidade'..."
    
    use "base_placebo_mort.dta", clear
    
    if `cidade' == 310400 {
        local capture_opt "" 
    }
    else {
        local capture_opt "capture"
    }
    
    * SYNTH DA MORTALIDADE
    `capture_opt' synth variavel_interesse ///
          variavel_interesse(2002(1)2004) ///
          variavel_interesse(2004) ///
          pib_pc(2002(1)2004) ///
          bx_peso(2002(1)2004) ///
          pop(2002(1)2004) ///
          , trunit(`cidade') trperiod(2005) ///
          keep(res_temp.dta) replace
          
    if _rc == 0 {
        use res_temp.dta, clear
        gen gap = _Y_treated - _Y_synthetic
        gen double id_cidade = `cidade'
        
        local N = _N
        forvalues i = 1/`N' {
            local ano_val = _time[`i']
            local gap_val = gap[`i']
            post buffer (`cidade') (`ano_val') (`gap_val')
        }
    }
}
postclose buffer

* 4. CALCULAR MSPE E PLOTAR
use "resultados_placebo_mort.dta", clear

gen gap_sq = gap^2
bysort id_cidade: egen mspe_pre = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_final = max(mspe_pre)

* Pega o MSPE de Araxá
sum mspe_final if id_cidade == 310400
local mspe_araxa = r(mean)

if `mspe_araxa' == . {
    display as error "ERRO CRÍTICO: Araxá não rodou!"
    exit
}

* Remove placebos ruins (> 20x erro de Araxá)
gen razao_mspe = mspe_final / `mspe_araxa'
drop if razao_mspe > 20 & id_cidade != 310400

* 5. O GRÁFICO FINAL
gen is_araxa = (id_cidade == 310400)
sort id_cidade ano 

twoway (line gap ano if is_araxa == 0, lcolor(gs12) lwidth(thin) connect(L)) ///
       (line gap ano if is_araxa == 1, lcolor(red) lwidth(thick) connect(L)) ///
       , legend(order(2 "Araxá" 1 "Placebos (Outras Cidades)")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       yline(0, lpattern(solid) lcolor(black)) ///
       title("Teste de Placebo no Espaço: Mortalidade Infantil") ///
       subtitle("Araxá vs Outras Cidades Mineiras") ///
       xtitle("Ano") ytitle("Gap (Real - Sintético)") ///
       note("Nota: Placebos com MSPE pré-intervenção > 20x Araxá foram removidos.")
	   
* ============================================================================================================================	   	   
* =========================================================
* BLOCO 10-BX: PLACEBO NO ESPAÇO (BAIXO PESO AO NASCER)
* =========================================================

clear all
set matsize 1000
set memory 500m

* 1. PREPARAÇÃO DA BASE
use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear
destring id_municipio_6 id_ano, replace force
keep if id_uf == "MG"
drop if id_ano < 2002 | id_ano > 2021
xtset id_municipio_6 id_ano
tsfill

* --- VARIÁVEL DE INTERESSE: BAIXO PESO ---
rename ind_baixo_peso_pct       variavel_interesse

* --- PREDITORES ---
rename ind_pib_pc_real_mil      pib_pc
rename bruto_populacao          pop
rename ind_mortalidade_infantil mort_inf 

* Interpolação
foreach var in variavel_interesse pib_pc pop mort_inf {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 2. DEFINIR O "POOL" DO PLACEBO (SORTEIO INTELIGENTE)
* Filtro: Cidades > 5.000 hab
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

* --- SORTEIO SEGURO (Araxá + 39 cidades) ---
preserve
    keep id_municipio_6
    duplicates drop
    
    set seed 12345
    gen sorteio = runiform()
    
    * Garante Araxá no topo
    replace sorteio = -1 if id_municipio_6 == 310400
    
    sort sorteio
    keep in 1/40
    
    save "lista_placebos_bx.dta", replace
restore
* -------------------------------------------

merge m:1 id_municipio_6 using "lista_placebos_bx.dta"
keep if _merge == 3
drop _merge

save "base_placebo_bx.dta", replace

* 3. O LOOP DO PLACEBO
postfile buffer double id_cidade ano gap using "resultados_placebo_bx.dta", replace

levelsof id_municipio_6, local(lista_cidades)

foreach cidade of local lista_cidades {
    
    noisily display "Rodando Baixo Peso para cidade: `cidade'..."
    
    use "base_placebo_bx.dta", clear
    
    if `cidade' == 310400 {
        local capture_opt "" 
    }
    else {
        local capture_opt "capture"
    }
    
    * SYNTH DO BAIXO PESO
    `capture_opt' synth variavel_interesse ///
          variavel_interesse(2002(1)2004) ///
          variavel_interesse(2004) ///
          pib_pc(2002(1)2004) ///
          mort_inf(2002(1)2004) ///
          pop(2002(1)2004) ///
          , trunit(`cidade') trperiod(2005) ///
          keep(res_temp.dta) replace
          
    if _rc == 0 {
        use res_temp.dta, clear
        gen gap = _Y_treated - _Y_synthetic
        gen double id_cidade = `cidade'
        
        local N = _N
        forvalues i = 1/`N' {
            local ano_val = _time[`i']
            local gap_val = gap[`i']
            post buffer (`cidade') (`ano_val') (`gap_val')
        }
    }
}
postclose buffer

* 4. CALCULAR MSPE E PLOTAR
use "resultados_placebo_bx.dta", clear

gen gap_sq = gap^2
bysort id_cidade: egen mspe_pre = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_final = max(mspe_pre)

* Pega o MSPE de Araxá
sum mspe_final if id_cidade == 310400
local mspe_araxa = r(mean)

if `mspe_araxa' == . {
    display as error "ERRO CRÍTICO: Araxá não rodou!"
    exit
}

* Remove placebos ruins (> 100x erro de Araxá)
gen razao_mspe = mspe_final / `mspe_araxa'
drop if razao_mspe > 100 & id_cidade != 310400

* 5. O GRÁFICO FINAL
gen is_araxa = (id_cidade == 310400)
sort id_cidade ano 

twoway (line gap ano if is_araxa == 0, lcolor(gs12) lwidth(thin) connect(L)) ///
       (line gap ano if is_araxa == 1, lcolor(red) lwidth(thick) connect(L)) ///
       , legend(order(2 "Araxá" 1 "Placebos (Outras Cidades)")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       yline(0, lpattern(solid) lcolor(black)) ///
       title("Teste de Placebo no Espaço: Baixo Peso ao Nascer") ///
       subtitle("Araxá vs Outras Cidades Mineiras") ///
       xtitle("Ano") ytitle("Gap (Real - Sintético)") ///
       note("Nota: Placebos com MSPE pré-intervenção > 20x Araxá foram removidos.")	   
	   
* ============================================================================================================================	   	   
* =========================================================
* BLOCO 10-RESP: PLACEBO NO ESPAÇO (INTERNAÇÕES RESPIRATÓRIAS)
* =========================================================

clear all
set matsize 1000
set memory 500m

* 1. PREPARAÇÃO DA BASE
use "C:\Users\fabio\TCC\FINALIZADOS\BASE_MINAS_PAINEL_COMPLETA.dta", clear
destring id_municipio_6 id_ano, replace force
keep if id_uf == "MG"
drop if id_ano < 2002 | id_ano > 2021
xtset id_municipio_6 id_ano
tsfill

* --- VARIÁVEL DE INTERESSE: INTERNAÇÕES RESPIRATÓRIAS ---
rename ind_internacoes_resp_por_mil variavel_interesse

* --- PREDITORES ---
rename ind_pib_pc_real_mil      pib_pc
rename bruto_populacao          pop
rename ind_mortalidade_infantil mort_inf 

* Interpolação
foreach var in variavel_interesse pib_pc pop mort_inf {
    by id_municipio_6: ipolate `var' id_ano, gen(temp_`var') epolate
    drop `var'
    rename temp_`var' `var'
}

* 2. DEFINIR O "POOL" DO PLACEBO (SORTEIO INTELIGENTE)
* Filtro: Cidades > 5.000 hab
bysort id_municipio_6: egen pop_media = mean(pop)
keep if id_municipio_6 == 310400 | pop_media > 5000

* --- SORTEIO SEGURO (Araxá + 39 cidades) ---
preserve
    keep id_municipio_6
    duplicates drop
    
    set seed 12345
    gen sorteio = runiform()
    
    * Garante Araxá no topo
    replace sorteio = -1 if id_municipio_6 == 310400
    
    sort sorteio
    keep in 1/40
    
    save "lista_placebos_resp.dta", replace
restore
* -------------------------------------------

merge m:1 id_municipio_6 using "lista_placebos_resp.dta"
keep if _merge == 3
drop _merge

save "base_placebo_resp.dta", replace

* 3. O LOOP DO PLACEBO
postfile buffer double id_cidade ano gap using "resultados_placebo_resp.dta", replace

levelsof id_municipio_6, local(lista_cidades)

foreach cidade of local lista_cidades {
    
    noisily display "Rodando Respiratória para cidade: `cidade'..."
    
    use "base_placebo_resp.dta", clear
    
    if `cidade' == 310400 {
        local capture_opt "" 
    }
    else {
        local capture_opt "capture"
    }
    
    * SYNTH (SEM NESTED)
    `capture_opt' synth variavel_interesse ///
          variavel_interesse(2002(1)2004) ///
          variavel_interesse(2004) ///
          pib_pc(2002(1)2004) ///
          mort_inf(2002(1)2004) ///
          pop(2002(1)2004) ///
          , trunit(`cidade') trperiod(2005) ///
          keep(res_temp.dta) replace
          
    if _rc == 0 {
        use res_temp.dta, clear
        gen gap = _Y_treated - _Y_synthetic
        gen double id_cidade = `cidade'
        
        local N = _N
        forvalues i = 1/`N' {
            local ano_val = _time[`i']
            local gap_val = gap[`i']
            post buffer (`cidade') (`ano_val') (`gap_val')
        }
    }
}
postclose buffer

* 4. CALCULAR MSPE E PLOTAR
use "resultados_placebo_resp.dta", clear

gen gap_sq = gap^2
bysort id_cidade: egen mspe_pre = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_final = max(mspe_pre)

* Pega o MSPE de Araxá
sum mspe_final if id_cidade == 310400
local mspe_araxa = r(mean)

if `mspe_araxa' == . {
    display as error "ERRO CRÍTICO: Araxá não rodou!"
    exit
}

* FILTRO DE QUALIDADE (Usei > 50x para garantir que o gráfico não fique vazio)
gen razao_mspe = mspe_final / `mspe_araxa'
drop if razao_mspe > 50 & id_cidade != 310400

* 5. O GRÁFICO FINAL
gen is_araxa = (id_cidade == 310400)
sort id_cidade ano 

twoway (line gap ano if is_araxa == 0, lcolor(gs12) lwidth(thin) connect(L)) ///
       (line gap ano if is_araxa == 1, lcolor(red) lwidth(thick) connect(L)) ///
       , legend(order(2 "Araxá" 1 "Placebos (Outras Cidades)")) ///
       xline(2005, lpattern(dot) lcolor(black)) ///
       yline(0, lpattern(solid) lcolor(black)) ///
       title("Teste de Placebo: Internações Respiratórias") ///
       subtitle("Araxá vs Outras Cidades Mineiras") ///
       xtitle("Ano") ytitle("Gap (Real - Sintético)") ///
       note("Nota: Placebos com MSPE pré-intervenção > 50x Araxá foram removidos.")	   
	   
* ============================================================================================================================	   
	   
* =========================================================
* BLOCO 11: RAZÃO RMSPE E P-VALOR (TESTE DE ROBUSTEZ FINAL)
* =========================================================

clear all

* 1. CARREGAR OS DADOS DO PLACEBO (Do Bloco 10-PIB)
use "resultados_placebo_pib.dta", clear

* 2. CALCULAR O ERRO QUADRÁTICO (GAP^2)
gen gap_sq = gap^2

* 3. CALCULAR MÉDIAS PRÉ E PÓS (MSPE)
* Pré: Antes de 2005
bysort id_cidade: egen mspe_pre_temp = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_pre = max(mspe_pre_temp)

* Pós: De 2005 para frente
bysort id_cidade: egen mspe_pos_temp = mean(gap_sq) if ano >= 2005
bysort id_cidade: egen mspe_pos = max(mspe_pos_temp)

* 4. REDUZIR A BASE PARA UMA LINHA POR CIDADE
* Mantemos apenas o ID, o MSPE e se é Araxá
collapse (max) mspe_pre mspe_pos, by(id_cidade)

gen is_araxa = (id_cidade == 310400)

* 5. CALCULAR A RAZÃO RMSPE (Post / Pre)
* Usamos a raiz quadrada (Sqrt) para transformar MSPE em RMSPE
gen rmspe_pre = sqrt(mspe_pre)
gen rmspe_pos = sqrt(mspe_pos)

gen ratio_rmspe = rmspe_pos / rmspe_pre

* ---------------------------------------------------------
* 6. CALCULAR O P-VALOR (A PROVA DOS 9)
* ---------------------------------------------------------
* Classificamos as cidades do maior Ratio para o menor
gsort -ratio_rmspe

* Verifica a posição de Araxá no Ranking
gen rank = _n
list id_cidade ratio_rmspe rank if is_araxa == 1

* Pega o valor exato de Araxá para usar no gráfico
sum ratio_rmspe if is_araxa == 1
local ratio_araxa = r(mean)

* Calcula o P-Valor: (Posição de Araxá) / (Total de Cidades)
count
local total_cidades = r(N)
count if ratio_rmspe >= `ratio_araxa'
local n_maiores_igual = r(N)
local p_valor = `n_maiores_igual' / `total_cidades'

display "---------------------------------------------------"
display "RESULTADO DO TESTE DE PERMUTAÇÃO (PIB per Capita):"
display "Razão RMSPE de Araxá: " `ratio_araxa'
display "Ranking de Araxá: " `n_maiores_igual' "º lugar de " `total_cidades'
display "P-Valor: " `p_valor'
display "---------------------------------------------------"

* ---------------------------------------------------------
* 7. O GRÁFICO DE DISTRIBUIÇÃO (HISTOGRAMA)
* ---------------------------------------------------------
* Filtro opcional: remove outliers absurdos dos placebos para o gráfico não ficar feio
* (Isso não altera o p-valor calculado acima, só a visualização)
summarize ratio_rmspe, detail
drop if ratio_rmspe > r(p99) & is_araxa == 0

twoway (histogram ratio_rmspe, frequency color(gs12) lcolor(black)) ///
       (pci 0 `ratio_araxa' 5 `ratio_araxa', lcolor(red) lwidth(thick) lpattern(solid)), ///
       legend(order(2 "Araxá" 1 "Distribuição dos Placebos")) ///
       title("Distribuição das Razões RMSPE (PIB per Capita)") ///
       subtitle("Araxá vs Controle Sintético (Placebos)") ///
       xtitle("Razão RMSPE (Pós/Pré)") ytitle("Frequência") ///
       note("P-Valor calculado: `p_valor'")
	   
* ============================================================================================================================	   
* =========================================================
* BLOCO 11-MORT: RAZÃO RMSPE E P-VALOR (MORTALIDADE INFANTIL)
* =========================================================

clear all

* 1. CARREGAR OS DADOS DO PLACEBO DE MORTALIDADE
* Certifique-se de que este arquivo foi criado no Bloco 10-MORT
use "resultados_placebo_mort.dta", clear

* 2. CALCULAR O ERRO QUADRÁTICO (GAP^2)
gen gap_sq = gap^2

* 3. CALCULAR MÉDIAS PRÉ E PÓS (MSPE)
* Pré: Antes de 2005
bysort id_cidade: egen mspe_pre_temp = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_pre = max(mspe_pre_temp)

* Pós: De 2005 para frente
bysort id_cidade: egen mspe_pos_temp = mean(gap_sq) if ano >= 2005
bysort id_cidade: egen mspe_pos = max(mspe_pos_temp)

* 4. REDUZIR A BASE PARA UMA LINHA POR CIDADE
collapse (max) mspe_pre mspe_pos, by(id_cidade)

gen is_araxa = (id_cidade == 310400)

* 5. CALCULAR A RAZÃO RMSPE (Post / Pre)
gen rmspe_pre = sqrt(mspe_pre)
gen rmspe_pos = sqrt(mspe_pos)

gen ratio_rmspe = rmspe_pos / rmspe_pre

* ---------------------------------------------------------
* 6. CALCULAR O P-VALOR
* ---------------------------------------------------------
gsort -ratio_rmspe
gen rank = _n

* Mostra a posição de Araxá no console
list id_cidade ratio_rmspe rank if is_araxa == 1

sum ratio_rmspe if is_araxa == 1
local ratio_araxa = r(mean)

count
local total_cidades = r(N)
count if ratio_rmspe >= `ratio_araxa'
local n_maiores_igual = r(N)
local p_valor = `n_maiores_igual' / `total_cidades'

display "---------------------------------------------------"
display "RESULTADO (MORTALIDADE INFANTIL):"
display "Razão RMSPE de Araxá: " `ratio_araxa'
display "Ranking de Araxá: " `n_maiores_igual' "º lugar de " `total_cidades'
display "P-Valor: " `p_valor'
display "---------------------------------------------------"

* ---------------------------------------------------------
* 7. O GRÁFICO DE DISTRIBUIÇÃO (HISTOGRAMA)
* ---------------------------------------------------------
* Filtro visual para remover outliers extremos dos placebos (se houver)
summarize ratio_rmspe, detail
drop if ratio_rmspe > r(p99) & is_araxa == 0

twoway (histogram ratio_rmspe, frequency color(gs12) lcolor(black)) ///
       (pci 0 `ratio_araxa' 5 `ratio_araxa', lcolor(red) lwidth(thick) lpattern(solid)), ///
       legend(order(2 "Araxá" 1 "Distribuição dos Placebos")) ///
       title("Razão RMSPE: Mortalidade Infantil") ///
       subtitle("Comparação de Significância Estatística") ///
       xtitle("Razão RMSPE (Pós/Pré)") ytitle("Frequência") ///
       note("P-Valor calculado: `p_valor'")

* ============================================================================================================================	   
* =========================================================
* BLOCO 11-BX: RAZÃO RMSPE E P-VALOR (BAIXO PESO)
* =========================================================

clear all

* 1. CARREGAR OS DADOS DO PLACEBO DE BAIXO PESO
* Certifique-se de que este arquivo foi criado no Bloco 10-BX
use "resultados_placebo_bx.dta", clear

* 2. CALCULAR O ERRO QUADRÁTICO (GAP^2)
gen gap_sq = gap^2

* 3. CALCULAR MÉDIAS PRÉ E PÓS (MSPE)
* Pré: Antes de 2005
bysort id_cidade: egen mspe_pre_temp = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_pre = max(mspe_pre_temp)

* Pós: De 2005 para frente
bysort id_cidade: egen mspe_pos_temp = mean(gap_sq) if ano >= 2005
bysort id_cidade: egen mspe_pos = max(mspe_pos_temp)

* 4. REDUZIR A BASE PARA UMA LINHA POR CIDADE
collapse (max) mspe_pre mspe_pos, by(id_cidade)

gen is_araxa = (id_cidade == 310400)

* 5. CALCULAR A RAZÃO RMSPE (Post / Pre)
gen rmspe_pre = sqrt(mspe_pre)
gen rmspe_pos = sqrt(mspe_pos)

gen ratio_rmspe = rmspe_pos / rmspe_pre

* ---------------------------------------------------------
* 6. CALCULAR O P-VALOR
* ---------------------------------------------------------
gsort -ratio_rmspe
gen rank = _n

* Mostra a posição de Araxá no console
list id_cidade ratio_rmspe rank if is_araxa == 1

sum ratio_rmspe if is_araxa == 1
local ratio_araxa = r(mean)

count
local total_cidades = r(N)
count if ratio_rmspe >= `ratio_araxa'
local n_maiores_igual = r(N)
local p_valor = `n_maiores_igual' / `total_cidades'

display "---------------------------------------------------"
display "RESULTADO (BAIXO PESO AO NASCER):"
display "Razão RMSPE de Araxá: " `ratio_araxa'
display "Ranking de Araxá: " `n_maiores_igual' "º lugar de " `total_cidades'
display "P-Valor: " `p_valor'
display "---------------------------------------------------"

* ---------------------------------------------------------
* 7. O GRÁFICO DE DISTRIBUIÇÃO (HISTOGRAMA)
* ---------------------------------------------------------
* Filtro visual para o gráfico ficar bonito (remove outliers extremos dos placebos)
summarize ratio_rmspe, detail
drop if ratio_rmspe > r(p99) & is_araxa == 0

twoway (histogram ratio_rmspe, frequency color(gs12) lcolor(black)) ///
       (pci 0 `ratio_araxa' 5 `ratio_araxa', lcolor(red) lwidth(thick) lpattern(solid)), ///
       legend(order(2 "Araxá" 1 "Distribuição dos Placebos")) ///
       title("Razão RMSPE: Baixo Peso ao Nascer") ///
       subtitle("Comparação de Significância Estatística") ///
       xtitle("Razão RMSPE (Pós/Pré)") ytitle("Frequência") ///
       note("P-Valor calculado: `p_valor'")

* ============================================================================================================================	   

* =========================================================
* BLOCO 11-RESP: RAZÃO RMSPE E P-VALOR (RESPIRATÓRIA)
* =========================================================

clear all

* 1. CARREGAR OS DADOS DO PLACEBO RESPIRATÓRIO
* Certifique-se de que este arquivo foi criado no Bloco 10-RESP
use "resultados_placebo_resp.dta", clear

* 2. CALCULAR O ERRO QUADRÁTICO (GAP^2)
gen gap_sq = gap^2

* 3. CALCULAR MÉDIAS PRÉ E PÓS (MSPE)
* Pré: Antes de 2005
bysort id_cidade: egen mspe_pre_temp = mean(gap_sq) if ano < 2005
bysort id_cidade: egen mspe_pre = max(mspe_pre_temp)

* Pós: De 2005 para frente
bysort id_cidade: egen mspe_pos_temp = mean(gap_sq) if ano >= 2005
bysort id_cidade: egen mspe_pos = max(mspe_pos_temp)

* 4. REDUZIR A BASE PARA UMA LINHA POR CIDADE
collapse (max) mspe_pre mspe_pos, by(id_cidade)

gen is_araxa = (id_cidade == 310400)

* 5. CALCULAR A RAZÃO RMSPE (Post / Pre)
gen rmspe_pre = sqrt(mspe_pre)
gen rmspe_pos = sqrt(mspe_pos)

gen ratio_rmspe = rmspe_pos / rmspe_pre

* ---------------------------------------------------------
* 6. CALCULAR O P-VALOR
* ---------------------------------------------------------
gsort -ratio_rmspe
gen rank = _n

* Mostra a posição de Araxá no console
list id_cidade ratio_rmspe rank if is_araxa == 1

sum ratio_rmspe if is_araxa == 1
local ratio_araxa = r(mean)

count
local total_cidades = r(N)
count if ratio_rmspe >= `ratio_araxa'
local n_maiores_igual = r(N)
local p_valor = `n_maiores_igual' / `total_cidades'

display "---------------------------------------------------"
display "RESULTADO (INTERNAÇÕES RESPIRATÓRIAS):"
display "Razão RMSPE de Araxá: " `ratio_araxa'
display "Ranking de Araxá: " `n_maiores_igual' "º lugar de " `total_cidades'
display "P-Valor: " `p_valor'
display "---------------------------------------------------"

* ---------------------------------------------------------
* 7. O GRÁFICO DE DISTRIBUIÇÃO (HISTOGRAMA)
* ---------------------------------------------------------
* Filtro visual para remover outliers extremos dos placebos (apenas estética)
summarize ratio_rmspe, detail
drop if ratio_rmspe > r(p99) & is_araxa == 0

twoway (histogram ratio_rmspe, frequency color(gs12) lcolor(black)) ///
       (pci 0 `ratio_araxa' 5 `ratio_araxa', lcolor(red) lwidth(thick) lpattern(solid)), ///
       legend(order(2 "Araxá" 1 "Distribuição dos Placebos")) ///
       title("Razão RMSPE: Internações Respiratórias") ///
       subtitle("Comparação de Significância Estatística") ///
       xtitle("Razão RMSPE (Pós/Pré)") ytitle("Frequência") ///
       note("P-Valor calculado: `p_valor'")
