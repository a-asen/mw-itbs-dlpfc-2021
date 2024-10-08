library(ProjectTemplate)
# migrate.project() # you might need to run this before everything loads properly. 
load.project()

# Exploratory analyses

### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 
#' These toggles makes it easy to return the various aspects your might want 
#' and nevertheless run the whole script without necessarily all the other aspects

script_save_with_date_time <- TRUE
#' **TRUE** will save all generated output with a date and time. 
#' This way you will not append previously generated data 
#' **FALSE** will not save the generated output with a date and time.
#' *CAUSTION* This feature might append previously generated data/tables/pictures

script_run_bayesian_models <- FALSE 
#' **TRUE** will **RUN** the Bayesian models.
#' Depending on your computer, this might take some time. 
#' **FALSE** will **NOT RUN** any Bayesian models, but will load them 
#' from "export/paper_vars.RData".

script_save_bayesian_models <- FALSE
#' **TRUE** will SAVE the generated Bayesian models.¤
#' **FALSE** will NOT SAVE the generated Bayesian models.¤
#' ¤ *if the "script_run_bayesian_models" is set to* **TRUE**.

# Toggles           =====
script_save_figures <- FALSE
#' **TRUE** will save figure 
#' **FALSE** will *NOT* save figures

script_save_tables <- FALSE
#' **TRUE** will save tables 
#' **FALSE** will *NOT* save tables
  
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### 

if(script_save_with_date_time){
  toggle_date_time <- format( Sys.time(), "%Y-%m-%d_%H-%M-%S_")
} else {
  toggle_date_time <- NULL
}

# Prepare data:
# Reverse the probes (higher value correspond to the probe Q)
d.pro.stim_pfc |> 
  mutate(
    probe1 = ordered(5-as.numeric(probe1)),
    probe2 = ordered(5-as.numeric(probe2)),
    probe3 = ordered(5-as.numeric(probe3)),
    probe1_n = as.integer(probe1),
    probe2_n = as.integer(probe2),
    probe3_n = as.integer(probe3),
    fatigue1 = as.integer(fatigue),
    stimulation = factor(stimulation, levels = c("sham", "real")),
    meditation1 = ifelse(meditation>0, 1, 0), #as.integer(meditation),
    music_year1 = ifelse(music_year>0, 1, 0), 
  ) -> pfc

# Pre-test      =====
## TMS expectation =====
# Test whether the expectation of the effect of the stimulation had an effect (?) 

### Prepare the data    ======
pfc |> 
  mutate(subj2 = as.numeric( str_split(subj, "PFC") |> map_chr(2)) ) |>
  summarise(
    .by = c(subj2, stimulation),
    session = unique(session),
    mw = mean(probe1_n),
    bv = mean(zlogbv),
    ae = mean(zlogapen)
  ) |>
  left_join(
    demo_pfc |> 
      select(subj, S1_TMS_expectation, S2_TMS_expectation) |> 
      pivot_longer(ends_with("expectation"),  values_to = "expectation") |>
      mutate(name = str_split(name, "_") |> map_chr(1)),
    by = join_by(subj2==subj, session==name)
  ) -> pfc_exp_sum

#' 0 = "No expectation" 
#' 1 = "Yes, increase" 
#' 2 = "Yes, reduce"
#' 3 = "Yes, but not how" 
#' 4 = "Don't know"


### Table         =======
tms_expectation_tbl <- 
  pfc_exp_sum |>
  filter(expectation %in% c(0, 1, 2)) |>
  pivot_longer(c(mw,bv,ae)) |>
  summarise(
    .by = name, 
    no_m = mean(value[expectation==0]),
    no_sd = sd(value[expectation==0]),
    i_m = mean(value[expectation==1]),
    i_sd = sd(value[expectation==1]),
    d_m = mean(value[expectation==2]),
    d_sd = sd(value[expectation==2]),
    i_mdiff    = mean(value[expectation==1]) - mean(value[expectation==0]), 
    i_t    = t.test(value[expectation==1], value[expectation==0])$statistic,
    i_df   = t.test(value[expectation==1], value[expectation==0])$parameter,
    i_p    = t.test(value[expectation==1], value[expectation==0])$p.value,
    i_bf01 = 1/extractBF(ttestBF(value[expectation==1], value[expectation==0]))$bf,
    d_mdiff    = mean(value[expectation==2]) - mean(value[expectation==0]), 
    d_t    = t.test(value[expectation==2], value[expectation==0])$statistic,
    d_df   = t.test(value[expectation==2], value[expectation==0])$parameter,
    d_p    = t.test(value[expectation==2], value[expectation==0])$p.value,
    d_bf01 = 1/extractBF(ttestBF(value[expectation==2], value[expectation==0]))$bf
  ) |>
  mutate(
    across(ends_with("_p"), ~fmt_APA_numbers(.x, .p=T)),
    across(where(is.double), ~fmt_APA_numbers(.x)),
    e="", e2="",
    name = fct_recode(name, MW="mw", BV="bv",AE="ae")
  ) |>
  rename(Variable="name") |>
  gt() |>
  tab_spanner("Increase", starts_with("i_")) |>
  tab_spanner("Decrease", starts_with("d_")) |>
  tab_spanner("No expectation", starts_with("no_")) |>
  cols_move(e, i_bf01) |>
  cols_move(e2, no_sd) |>
  cols_label(
    ends_with("_m")~md("*M*"),
    ends_with("_t")~md("*t*"),
    ends_with("_df")~md("*df*"),
    ends_with("_p")~md("*p*"),
    ends_with("_bf01")~md("BF~01~"), 
    ends_with("_sd") ~md("*SD*"),
    ends_with("diff") ~ md("*M*~diff~"),
    starts_with("e") ~"",
  ) |>
  cols_align("center")
tms_expectation_tbl

if(script_save_tables){
  gtsave(tms_expectation_tbl, paste0("tables/",toggle_date_time,"tms_expectation_table.docx"))
}


##  Music & Meditation        =====
### Descriptives           =====
tbl_descriptives_mus_med <-
  pfc |> 
  pivot_longer(c(meditation1, music_year1), names_to = "cat", values_to="cat_val") |>
  summarise(
    .by = c(subj, cat),
    cat_v = unique(cat_val),
    mw = mean(probe1_n),
    ae = mean(zlogapen),
    bv = mean(zlogbv)
  ) |>
  pivot_longer(c(mw,ae,bv)) |>
  summarise(
    .by = c(cat, cat_v, name),
    n = n(),
    m = mean(value, na.rm=T),
    sd = mean(value, na.rm=T)
  ) |>
  pivot_wider(names_from = cat_v, values_from=c(n,m,sd)) |>
  mutate(mdiff = m_1 - m_0) |>
  pivot_wider(names_from = cat, values_from=matches("(_0|_1|diff)$")) |>
  mutate(
    across(c(everything(), -starts_with("n_") ), ~fmt_APA_numbers(.x, .chr=T)),
    name =ifelse(name=="mw", "MW", ifelse(name=="bv", "BV", "AE")),
    e="", e_meditation1="",e_music_year1="",
  ) |>
  gt() |> 
  tab_spanner("Any", contains("_1_")) |>
  tab_spanner("No", contains("_0_")) |>
  tab_spanner("Music", ends_with("music_year1")) |>  
  tab_spanner("Meditation", ends_with("meditation1")) |>
  cols_move(ends_with("meditation1"), name) |>
  cols_move(contains("_0_meditation"), name) |>
  cols_move(contains("_0_music_year1"), mdiff_meditation1) |>
  cols_move(e, mdiff_meditation1) |>
  cols_move(e_meditation1, sd_0_meditation1) |>
  cols_move(e_music_year1, sd_0_music_year1) |>
  cols_align("center", c(everything(),-name)) |>
  cols_label(
    starts_with("n_") ~ "n",
    starts_with("m_") ~ md("*M*"),
    starts_with("sd_") ~ md("*SD*"),
    starts_with("mdiff") ~ md("*M*~diff~"),
    starts_with("e") ~ "",
  ) |>
  tab_footnote(
    md(
      "*Note*. Fourteen people reported to have no meditation while 26 reported 
      that they had meditation experience. With respect to musical experience, 
      16 reported that they had no experience, while 24 reported that they had 
      musical experience."
    )
  ) |>
  cols_hide(starts_with("n_"))

tbl_descriptives_mus_med
if(script_save_tables){
  gtsave(tbl_descriptives_mus_med, 
         paste0("tables/", toggle_date_time, "music_meditation_desciptives.docx"))
}

### Freq stats - prepare the data          =====
m_m_data <- 
  pfc |> 
  pivot_longer(c(meditation1, music_year1), names_to = "cat", values_to="cat_val") |>
  mutate(probe1_n = scale(probe1_n)) |>
  summarise(
    .by = c(subj, cat),
    cat_v = unique(cat_val),
    mw = mean(probe1_n),
    ae = mean(zlogapen),
    bv = mean(zlogbv)) |>
  pivot_longer(c(mw,bv,ae))

#### Table                    =====
music_meditation_tbl <- 
  m_m_data |>
  summarise(
    .by = c(cat, name), 
    m0_m  = mean(value[cat_v==0]),
    m0_sd = sd(value[cat_v==0]),
    m1_m  = mean(value[cat_v==1]),
    m1_sd = sd(value[cat_v==1]),
    mdiff = mean(value[cat_v==1]) - mean(value[cat_v==0]),
    t  = t.test(value[cat_v==1], value[cat_v==0])$statistic, 
    df = t.test(value[cat_v==1], value[cat_v==0])$parameter, 
    p  = t.test(value[cat_v==1], value[cat_v==0])$p.value, 
    bf = 1/extractBF( ttestBF(value[cat_v==1], value[cat_v==0]) )$bf
  ) |> 
  mutate(.by = cat, p.adj = p.adjust(p, "bonferroni")) |> 
  mutate(
    across( contains("p"), ~fmt_APA_numbers(.x, .p = T) ),
    across( where(is.double), ~fmt_APA_numbers(.x) ),
    name = fct_recode(name, MW="mw", BV="bv", AE="ae"),
    cat = fct_recode(cat, Meditation="meditation1", Music="music_year1"),
    e="", e2="", 
  ) |>
  rename(Variable="name") |>
  gt(groupname_col = "cat") |>
  tab_spanner("No experience", starts_with("m0_")) |>
  tab_spanner("Any experience", starts_with("m1_")) |>
  cols_label(
    ends_with("_m") ~ md("*M*"),
    ends_with("_sd") ~ md("*SD*"),
    t=md("*t*"), df = md("*df*"), p=md("*p*"), p.adj = md("*p*~adj~"), 
    bf = md("BF~01~"), mdiff=md("*M*~diff~"),
    starts_with("e")~""
  ) |>
  cols_move(p.adj, p) |>
  cols_move(e, m0_sd) |>
  cols_move(e2, m1_sd) |>
  cols_align("center")

music_meditation_tbl
if(script_save_tables){
  gtsave(music_meditation_tbl, paste0("tables/",toggle_date_time,"meditation_and_musical_experience.docx"))
}

#### Figure      =====
m_m_figure <- 
  m_m_data |>
  mutate(
    cat_v = factor(cat_v, label=c("No", "Any")),
    cat   = ifelse(cat=="meditation1", "Meditation", "Music"),
    name  = fct_recode(name, AE="ae", BV="bv", MW="mw") |> 
      fct_relevel("MW","BV","AE")
  ) |>
  # pivot_wider(values_from=c(value), names_from=cat_v, names_expand = T)
  rename(Experience = cat_v) |>
  ggplot(aes(Experience, value, col=Experience)) + 
  facet_wrap(cat~name) +
  stat_summary(fun.data=mean_se) + 
  labs(y="Standardized values") +
  geom_hline(yintercept=0, linetype="dashed") + 
  theme(legend.position = "none") 

m_m_figure
if(script_save_figures){
  ggsave(m_m_figure, paste0("figs/exploratory/",toggle_date_time,"meditation_and_music.svg"))
}

### Bayes stats        ====
#### Models         ====
if(script_run_bayesian_models){
  mod.mw.music_medi <- brm(probe1 ~ stimulation + block*stimulation + 
                             music_year1 + meditation1 + scale(proberound) + (1|subj), 
                    init=0, family=cumulative("probit"), data=pfc, 
                    backend = "cmdstanr", chains = 6, iter=6000)
  bayes_plot(mod.music_medi)+ labs(title="Music and meditation model")
  summary(mod.music_medi)
  
  mod.bv.music_medi <- brm(zlogbv ~ stimulation + block*stimulation + 
                             music_year1 + meditation1 + scale(proberound) + (1|subj), 
                           init=0, data=pfc, 
                           backend = "cmdstanr", chains = 6, iter=6000)
  bayes_plot(mod.bv.music_medi)+ labs(title="Music and meditation model")
  summary(mod.bv.music_medi)
    
  mod.ae.music_medi <- brm(zlogapen ~ stimulation + block*stimulation + 
                             music_year1 + meditation1 + scale(proberound) + (1|subj), 
                           init=0, data=pfc, 
                           backend = "cmdstanr", chains = 6, iter=6000)
  bayes_plot(mod.ae.music_medi)+ labs(title="Music and meditation model")
  summary(mod.ae.music_medi)
  
  
  if(script_save_bayesian_models){
    save(mod.mw.music_medi, mod.bv.music_medi, mod.ae.music_medi,
         file = paste0("data/export/", toggle_date_time,
                       "bayesian_effect_of_music_meditaiton_on_mw-bv-ae.RData"))
  }
}
if(!scritp_run_bayesian_models){
    load("data/export/bayesian_effect_of_music_meditaiton_on_mw-bv-ae.RData")
}

#### Plot    ====
plot_bayes_bv_ae_music_medi <- 
  as_tibble(mod.bv.music_medi) |> 
  select(b_meditation1, b_music_year1) |>
  rename_with(~paste0("BV_", .x)) |> 
  bind_cols(
    as_tibble(mod.ae.music_medi) |> 
      select(b_meditation1, b_music_year1) |>
      rename_with(~paste0("AE_", .x))
  ) |>
  pivot_longer(everything()) |>
  separate_wider_delim(name, "_b_", names = c("dep", "params")) |>
  mutate(
    params = ifelse(params=="meditation1", "Meditation", "Music")
  ) |>
  ggplot(aes(params, value, col = params)) + 
  facet_wrap(~dep) +
  geom_hline(yintercept=0, linetype="dashed") +
  stat_summary(fun.data = mean_hdci) +
  labs(x="") +
  scale_y_continuous(breaks = seq(-.6,.6, .15), limits = c(-.6,.6)) +
  theme(legend.position="none") 

plot_bayes_bv_ae_music_medi
if(script_save_figures){
  ggsave(
    paste0(
      "figs/", toggle_date_time, "Meditation and music on BV and AE.svg"
    ), plot_bayes_bv_ae_music_medi, width = 6, height = 3)
}


plot_bayes_mw_music_medi <- 
  as_tibble(mod.music_medi) |> 
  select(b_meditation1, b_music_year1) |>
  mutate(name2 = "MW") |>
  pivot_longer(c(b_meditation1, b_music_year1)) |>
  mutate(
    name = ifelse(name=="b_meditation1", "Meditation", "Music")
  ) |>
  ggplot(aes(name, value, col = name)) +
  facet_wrap(~name2) +
  geom_hline(yintercept=0, linetype="dashed") +
  stat_summary(fun.data = mean_hdci) +
  scale_y_continuous(breaks = seq(-.6,.6, .15), limits = c(-.6,.6)) +
  labs(x = "", y = "Effect") +
  theme(legend.position = "none")

plot_bayes_mw_music_medi
if(script_save_figures){
  ggsave(
    paste0(
      "figs/", toggle_date_time, "Meditation and music on MW.svg"
    ), plot_bayes_mw_music_medi, width = 3, height = 3)
}


#### Table      ======
tbl_bay_effect_of_music_med <-
  as_tibble(mod.music_medi) |> 
  select(b_meditation1, b_music_year1) |>
  mutate(dep = "MW") |> 
  bind_rows(
    as_tibble(mod.bv.music_medi) |> 
      select(b_meditation1, b_music_year1) |>
      mutate(dep = "BV")
  ) |>
  bind_rows( 
    as_tibble(mod.ae.music_medi) |> 
      select(b_meditation1, b_music_year1) |>
      mutate(dep = "AE")
  ) |>
  pivot_longer(c(b_meditation1, b_music_year1)) |>
  mutate(name = ifelse(name=="b_meditation1", "Meditaiton", "Music")) |>
  summarise(
    .by = c(dep, name), 
    m   = fmt_APA_numbers( mean(value) ),
    hdi = bay_hdi(value, .chr=T),
    er  = bay_er(value, .chr=T),
    p   = bay_p(value, .p=T)
  ) |> pivot_wider(names_from=dep, values_from=c(everything(), -dep, -name)) |>
  mutate(e="", e2="") |>
  gt() |>
  tab_spanner("Mind wandering", ends_with("_MW")) |>
  tab_spanner("Behavioural variability", ends_with("_BV")) |>
  tab_spanner("Approximate entropy", ends_with("_AE")) |>
  cols_align("center", c(everything(), -name)) |>
  cols_move(e, "p_MW") |>
  cols_move(e2, "p_BV") |>
  cols_label(
    starts_with("m_") ~ md("*M*"),
    starts_with("hdi_") ~ "HDI",
    starts_with("er_") ~ md("ER~dir~"),
    starts_with("p_") ~ md("*p*~dir~"),
    name="", e="",e2=""
  )

tbl_bay_effect_of_music_med
if(script_save_figures){
  gtsave(tbl_bay_effect_of_music_med, 
         paste0("tables/", toggle_date_time, "evidence for effects of meditation and music.docx"))
}

# Post-test      =====

## Accumulating effects of TMS      =====
###  Frequentist statistics         =====

#' **NOT USED**

#### Table                           ======
accumen_data_tbl <- 
  pfc |>
  mutate(probe1_n = as.integer(probe1)) |>
  select(subj, region, stimulation, block, proberound, zlogapen, zlogbv, probe1_n) |>
  # baseline  (B0) correct
  pivot_longer(c(zlogapen, zlogbv, probe1_n), names_to="name", values_to = "val") |> 
  pivot_wider(names_from = c(block, name), values_from = val) |> 
  mutate(B0_ae=0,
         B1_ae=B1_zlogapen-B0_zlogapen,
         B2_ae=B2_zlogapen-B0_zlogapen,
         B3_ae=B3_zlogapen-B0_zlogapen,
         B0_bv=0,
         B1_bv=B1_zlogbv-B0_zlogbv,
         B2_bv=B2_zlogbv-B0_zlogbv,
         B3_bv=B3_zlogbv-B0_zlogbv,
         B0_mw=0,
         B1_mw=B1_probe1_n-B0_probe1_n,
         B2_mw=B2_probe1_n-B0_probe1_n,
         B3_mw=B3_probe1_n-B0_probe1_n) |> 
  select(-ends_with("zlogapen"), -ends_with("zlogbv"), -ends_with("probe1_n")) |>
  pivot_longer(starts_with("B"), names_to = c("block","variable"), names_sep = "_") |> 
  mutate(variable=fct_recode(variable, AE="ae",BV="bv",MW="mw"),
         variable=factor(variable, levels=c("MW","BV","AE"))) |>
  pivot_wider(names_from=stimulation, values_from=value) |>
  # calculate difference between cond
  summarise(
    .by=c(subj, block, variable), 
    sham = mean(sham),
    real = mean(real),
  ) |>
  mutate(diff = real-sham) |>
  select(-sham, -real) |>
  pivot_wider(names_from=c(block), values_from=diff) |>
  # take the difference between b1-b2 and b2-b3 
  mutate(B2 = B2 - B1, B3 = B3 - B2)  |> 
  pivot_longer(c(B1, B2, B3)) |>
  select(-B0) 


accumen_test_tbl <- 
  accumen_data_tbl |>
  mutate(nill = 0) |>
  summarise(
    .by    = c(variable, name), 
    m   = mean(value), 
    sd  = sd(value), 
    t   = t.test(value, mu=0)$statistic,
    df  = t.test(value, mu=0)$parameter,
    p   = t.test(value, mu=0)$p.value,
    d   = lsr::cohensD(value, nill, method="paired"),
    bf10  = extractBF(ttestBF(value, mu = 0))$bf,
  ) |> mutate(.by = variable, p.adj  = p.adjust(p, "bonferroni")) |>
  mutate(name=case_when(
    name=="B1"~"B1 - B0", 
    name=="B2"~"B2 - B1", 
    name=="B3"~"B3 - B2"),
    across(contains("p"), ~ fmt_APA_numbers(.x, .p=T)), 
    across(where(is.double), ~fmt_APA_numbers(.x))
  ) |> 
  pivot_wider(names_from=variable, values_from=c(m,sd,t,df,p,p.adj, bf10, d)) 
  

# Table
accumen_tbl <- 
  accumen_test_tbl |>
  mutate(e="", e2="") |>
  gt() |>
  tab_spanner("Mind Wandering", ends_with("MW")) |>
  tab_spanner("Behavioural Variability", ends_with("BV")) |>
  tab_spanner("Approximate Entropy", ends_with("AE")) |>
  cols_move(ends_with("MW"), name) |>
  cols_move(ends_with("BV"), bf10_MW) |>
  cols_move(e, bf10_MW) |>
  cols_move(d_MW, p.adj_MW ) |>
  cols_move(d_BV, p.adj_BV ) |>
  cols_move(e2, bf10_BV) |>
  cols_label(
    starts_with("m_") ~ md("*M*~diff~"),
    starts_with("sd_") ~ md("*SD*~diff~"),
    starts_with("t_") ~ md("*t*"),
    starts_with("df_") ~ md("*df*"),
    starts_with("p_") ~ md("*p*"),
    starts_with("p.adj_") ~ md("*p*~adj~"),
    starts_with("bf10_") ~ md("BF~10~"),
    starts_with("e") ~ "",
    starts_with("d_") ~ md("*d*")
  )

# Do not use freq here. 
# accumen_tbl
# if(script_save_tables){
#   gtsave(accumen_tbl, "tables/accumulating effect of the repeated tms.docx")
# }


###  Bayesian statistics               ======

# Based on the bayesian models done previously.

# Visualize whether the blocks are different
as_tibble(mod.pfc.mw) |>
  mutate(dep="MW") |>
  bind_rows(as_tibble(mod.pfc.bv) |> mutate(dep="BV")) |>
  bind_rows(as_tibble(mod.pfc.ae) |> mutate(dep="AE")) |>
  mutate(
    .before = 1,
    diffB1_B0 = `b_stimulationreal:blockB1` - 0,
    diffB2_B1 = `b_stimulationreal:blockB2` - `b_stimulationreal:blockB1`,
    diffB3_B2 = `b_stimulationreal:blockB3` - `b_stimulationreal:blockB2`,
  ) |>
  pivot_longer(c(diffB1_B0, diffB2_B1, diffB3_B2))  |>
  ggplot(aes(value)) +
  facet_wrap(dep~name) +
  geom_histogram() +
  geom_vline(xintercept = 0, col = "red")


# Test whether they the blocks are different
accumen_bays_tbl <- 
  as_tibble(mod.pfc.mw) |>
  mutate(dep="MW") |>
  bind_rows(as_tibble(mod.pfc.bv) |> mutate(dep="BV")) |>
  bind_rows(as_tibble(mod.pfc.ae) |> mutate(dep="AE")) |>
  mutate(
    .before = 1,
    diffB1_B0 = `b_stimulationreal:blockB1` - 0,
    diffB2_B1 = `b_stimulationreal:blockB2` - `b_stimulationreal:blockB1`,
    diffB3_B2 = `b_stimulationreal:blockB3` - `b_stimulationreal:blockB2`,
  ) |>
  pivot_longer(c(diffB1_B0, diffB2_B1, diffB3_B2)) |>
  summarise(
    .by = c(dep, name), 
    m   = mean(value) |> fmt_APA_numbers(num=_), 
    HDI = bay_hdi(value),
    ER  = bay_er(value),
    p   = bay_p(value),
    e ="",
    e2="", 
  )  |>
  mutate(
    name = ifelse(name=="diffB1_B0", "B1-B0", ifelse(name=="diffB2_B1", "B2-B1", "B3-B2"))
  ) |>
  pivot_wider(names_from=dep, values_from=c(m, HDI, ER, p)) |>
  gt() |>
  tab_spanner("Mind Wandering", ends_with("_MW")) |>
  tab_spanner("Behavioural variability", ends_with("_BV")) |>
  tab_spanner("Approximate entropy", ends_with("_AE")) |>
  cols_move(e, p_MW) |>
  cols_move(e2, p_BV) |>
  cols_align("center",c(everything(), -name)) |>
  cols_label(
    starts_with("m_")  ~ md("*M*"),
    starts_with("HDI_") ~ "HDI",
    starts_with("ER") ~ md("ER~dir~"),
    starts_with("p_") ~ md("*p*"),
    e="",e2="",
  )

accumen_bays_tbl
if(script_save_tables){
  gtsave(
    accumen_bays_tbl, 
    paste0("tables/", toggle_date_time,
           "Bayesian test of accumulating effects.docx")
    )
}


## Full Bayesian model            =====
if(script_run_bayesian_models){
  mod.mw_bv_ae <- 
    brm(
      probe1 ~ zlogapen*stimulation +  zlogbv*stimulation + stimulation*block + scale(proberound) + (1|subj), data = pfc,
      family = cumulative("probit"), chains = 6, iter=6000, cores=6, init=0, backend="cmdstanr" 
    )
  bayes_plot(mod.mw_bv_ae)
}

if(script_save_bayesian_data){
  save(mod.mw_bv_ae, file = paste0("data/export/", toggle_date_time, "mod_mw_bv+ae.RData"))
}

if(!script_run_bayesian_models){
  load("data/export/mod_mw_bv+ae.RData")
}

### Visualize BV+AE on MW - Bayesian                 =====

l_mod_table <- 
  as_tibble(mod.mw_bv_ae) |> 
  select(starts_with("b_"), sd_subj__Intercept) |>
  gather(variable,val) |>
  group_by(variable) |>
  summarize(
    pd   = bay_p(val, .low_val=T),
    b    = paste0( fmt_APA_numbers( mean(val), .chr=T ), ifelse(pd>.95, "*","") ), 
    hdi  = bay_hdi(val, .chr=T), 
    erat = bay_er(val, .chr=T),
    pd  = fmt_APA_numbers(pd, .p=T) 
  ) |>
  mutate(variable=fct_recode(
    variable,
    Threshold1="b_Intercept[1]", Threshold2="b_Intercept[2]", Threshold3="b_Intercept[3]", 
    # Block
    Trial="b_scaleproberound",  
    `Stimulation (B0)`="b_stimulationreal",
    B1="b_blockB1", 
    B2="b_blockB2", 
    B3="b_blockB3",
    `B1 x stimulation`="b_stimulationreal:blockB1", 
    `B2 x stimulation`="b_stimulationreal:blockB2",
    `B3 x stimulation`="b_stimulationreal:blockB3", 
    # --- --- BV  --- --- 
    BV = "b_zlogbv", 
    `BV x stimulation` = "b_stimulationreal:zlogbv", 
    # --- --- AE --- --- 
    AE = "b_zlogapen", 
    `AE x stimulation` = "b_zlogapen:stimulationreal",
    `Sigma (subjects)`="sd_subj__Intercept"),
    variable=ordered(variable, levels=c(
      "Threshold1", "Threshold2", "Threshold3",
      "Trial", "Stimulation (B0)", 
      "B1","B2","B3", 
      "B1 x stimulation", "B2 x stimulation", "B3 x stimulation",
      # --- --- BV --- --- 
      "BV",  "BV x stimulation", 
      # --- --- AE --- --- 
      "AE", "AE x stimulation", 
      "Sigma (subjects)"))
  ) |> 
  arrange(variable) |>
  mutate(
    group = case_when(
      variable %in% c("Sigma (subjects)") ~ "Model fit",
      T ~ "Coefficients")
  ) 

r2 <- brms::bayes_R2(mod.mw_bv_ae)
lo <- brms::loo(mod.mw_bv_ae)$estimates["looic",]

l_mod_table_last <- 
  l_mod_table |> 
  add_row(
    variable="R2", pd="", #²
    b = fmt_APA_numbers(r2[1], .chr = T, .p = T),
    hdi = sprintf("[%.2f, %.2f]", r2[3], r2[4]),
    group="Model fit"
  ) |>
  add_row(
    variable="LOOIC", pd="", 
    b = fmt_APA_numbers(lo[1], .chr=T),
    hdi = paste0("(SE=", fmt_APA_numbers(lo[2], .chr=T)),
    group = "Model fit"
  ) |>
  mutate(erat = fmt_APA_numbers(erat, .chr=T) ) |>
  gt(groupname_col = "group") |>
  cols_move(c(erat, pd), hdi) |>
  cols_label(
    b = md("*b*"), 
    erat = md("ER~dir~"),
    pd = md("*p*~dir~"),
    hdi = "HDI",
  ) |>
  cols_align("center", 2:6) 

l_mod_table_last
if(script_save_tables){
  gtsave(l_mod_table_last, paste0("tables/",toggle_date_time, "mod_bv+ae_on_MW.docx"))
}
