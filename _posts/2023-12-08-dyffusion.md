---
layout: distill
title:  "DYffusion: A Dynamics-informed Diffusion Model for Spatiotemporal Forecasting"
date:   2023-12-08
authors: 
    - name: Salva Rühling Cachay
      url: https://salvarc.github.io/
      affiliations:
        name: UC San Diego
bibliography: blogs.bib
paper_url: https://arxiv.org/abs/2306.01984
code_url: https://github.com/Rose-STL-Lab/dyffusion
description: We introduce a novel diffusion model-based framework, DYffusion, for large-scale probabilistic forecasting.
    We propose to couple the diffusion steps with the physical timesteps of the data, 
    leading to temporal forward and reverse processes that we represent through an interpolator and a forecaster network, respectively.
    DYffusion is faster than standard diffusion models during sampling, has low memory needs, and 
    effectively addresses the challenges of generating stable, accurate and probabilistic rollout forecasts.
comments: true
hidden: false

---

<d-contents>
  <nav class="l-text figcaption">
  <h3>Contents</h3>
    <div><a href="#introduction"> Introduction </a></div>
    <ul>
      <!--- <li><a href="#limitations-of-previous-work">Limitations of prior work</a></li> --->
      <li><a href="#our-key-idea"> Our key idea </a></li>
    </ul>
    <div><a href="#notation--background"> Notation & Background </a></div>
    <ul>
      <li><a href="#problem-setup"> Problem setup </a></li>
      <li><a href="#standard-diffusion-models"> Standard diffusion models </a></li>
    </ul>
    <div><a href="#dyffusion-dynamics-informed-diffusion-model"> DYffusion</a></div>
    <ul>
      <li><a href="#training-dyffusion"> Training DYffusion </a></li>
      <li><a href="#temporal-interpolation-as-a-forward-process"> Temporal interpolation as a forward process </a></li>
      <li><a href="#forecasting-as-a-reverse-process"> Forecasting as a reverse process </a></li>
      <li><a href="#sampling-from-dyffusion"> Sampling from DYffusion </a></li>
      <li><a href="#memory-footprint"> Memory footprint </a></li>
    </ul>
    <div><a href="#experimental-setup"> Experimental Setup </a></div>
    <ul>
      <li><a href="#datasets"> Datasets </a></li>
      <li><a href="#baselines"> Baselines </a></li>
      <li><a href="#neural-network-architectures"> Neural architectures </a></li>
      <li><a href="#evaluation-metrics"> Evaluation metrics </a></li>
    </ul>
    <div><a href="#results"> Results </a></div>
    <ul>
      <li><a href="#quantitative-results"> Quantitative </a></li>
      <li><a href="#qualitative-results"> Qualitative </a></li>
      <li><a href="#temporal-super-resolution-and-sample-variability"> Temporal super-resolution </a></li>
      <li><a href="#iterative-refinement-of-forecasts"> Iterative refinement </a></li>
    </ul>
    <div><a href="#conclusion"> Conclusion </a></div>
  </nav>
</d-contents>


<div class='l-body' align="center">
<img class="img-fluid rounded z-depth-1" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/diagram.gif">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px;">
DYffusion forecasts a sequence of $h$ snapshots $\mathbf{x}_1, \mathbf{x}_2, \ldots, \mathbf{x}_h$ 
given the initial conditions $\mathbf{x}_0$ similarly to how standard diffusion models are used to sample from a distribution.</figcaption>
</div>


## Introduction

Obtaining _accurate and reliable probabilistic forecasts_ has a wide range of applications from
climate simulations and fluid dynamics to financial markets and epidemiology.
Often, accurate _long-range_ probabilistic forecasts are particularly challenging to obtain <d-cite key="300BillionServed2009, gneiting2005weather,bevacqua2023smiles"></d-cite>.
When they exist, physics-based methods typically hinge on computationally expensive
numerical simulations <d-cite key="bauer2015thequiet"></d-cite>.
In contrast, data-driven methods are much more efficient and have started to have real-world impact
in fields such as [global weather forecasting](https://www.ecmwf.int/en/about/media-centre/news/2023/how-ai-models-are-transforming-weather-forecasting-showcase-data).

Common approaches for large-scale spatiotemporal problems tend to be _deterministic_ and _autoregressive_.
Thus, they are often unable to capture the inherent uncertainty in the data, produce unphysical predictions,
and are prone to error accumulation for long-range forecasts.

Diffusion models have shown great success for natural image and video generation.
However, diffusion models have been primarily designed for static data and are expensive to train and to sample from.
We study how we can _efficiently leverage them for large-scale spatiotemporal problems_ and _explicitly
incorporate the temporality of the data into the diffusion model_. 

[//]: # (Generative modeling, and especially diffusion models, have shown great success in other fields such as )
[//]: # (natural image generation, and video synthesis.)
[//]: # (Diffusion models iteratively transform data between an initial distribution)
[//]: # (and the target distribution over multiple diffusion steps<d-cite key="sohldickstein2015deepunsupervised, ho2020ddpm, karras2022edm"></d-cite>.)
[//]: # (The standard approach &#40;e.g. see [this excellent blog post]&#40;https://lilianweng.github.io/posts/2021-07-11-diffusion-models/&#41;&#41;)
[//]: # (corrupts the data with increasing levels of Gaussian noise in the forward process,)
[//]: # (and trains a neural network to denoise the data in the reverse process. )
[//]: # (Due to the need to generate data from noise over several sequential steps, )
[//]: # (diffusion models are expensive to train and, especially, to sample from.)
[//]: # (Recent works such as Cold Diffusion <d-cite key="bansal2022cold"></d-cite>, by which our work was especially inspired, )
[//]: # (have proposed to use alternative data corruption processes like blurring. )

[//]: # (#### Limitations of Previous Work)

[//]: # (Common approaches for large-scale spatiotemporal problems tend to be _deterministic_ and _autoregressive_.)
[//]: # (They are often unable to capture the inherent uncertainty in the data, produce unphysical predictions,)
[//]: # (and are prone to error accumulation for long-range forecasts. )
[//]: # (It is natural to ask how we can efficiently leverage diffusion models for large-scale spatiotemporal problems.)
[//]: # (Given that diffusion models have been primarily designed for static data, we also ask how we can explicitly)
[//]: # (incorporate the temporality of the data into the diffusion model.)

#### Our Key Idea

We introduce a solution for these issues by designing a temporal diffusion model, DYffusion.
Following the “generalized diffusion model” framework <d-cite key="bansal2022cold"></d-cite>, we
replace the forward and reverse processes of standard diffusion models
with dynamics-informed interpolation and forecasting, respectively.
This leads to a scalable generalized diffusion model for probabilistic forecasting that is naturally trained to forecast multiple timesteps.

[//]: # (--------------------------------------------------- Background -------------------------------)
## Notation & Background

#### Problem setup
We study the problem of probabilistic spatiotemporal forecasting using a dataset consisting of
a time series of snapshots $$ \mathbf{x}_t \in \mathcal{X}$$.
We focus on the task of forecasting a sequence of $$h$$ snapshots from a single initial condition. 
That is, we aim to train a model to learn $$P(\mathbf{x}_{t+1:t+h} \,|\, \mathbf{x}_t)$$ .
Note that during evaluation, we may evaluate the model on a larger horizon $$H>h$$ by running the model autoregressively.

[//]: # (Here, $$\mathcal{X}$$ represents the space in which the data lies, which )
[//]: # (may consist of spatial dimensions &#40;e.g., latitude, longitude, atmospheric height&#41; and a channel dimension &#40;e.g., velocities, temperature, humidity&#41;.)



#### Standard diffusion models

Diffusion models iteratively transform data between an initial distribution
and the target distribution over multiple diffusion steps<d-cite key="sohldickstein2015deepunsupervised, ho2020ddpm, karras2022edm"></d-cite>.
Here, we adapt the 
<a src="https://lilianweng.github.io/posts/2021-07-11-diffusion-models/#forward-diffusion-process">common notation for diffusion models</a> 
to use a superscript $$n$$ for the diffusion states $$\mathbf{s}^{(n)}$$, 
to distinguish them from the timesteps of the data, $$\mathbf{x}_t$$.
Given a data sample $$\mathbf{s}^{(0)}$$, a standard diffusion model is defined through a _forward diffusion process_ 
$$q(\mathbf{s}^{(n)} \vert \mathbf{s}^{(n-1)})$$
in which small amounts of Gaussian noise are added to the sample in $$N$$ steps, producing a sequence of noisy samples 
$$\mathbf{s}^{(1)}, \ldots, \mathbf{s}^{(N)}$$. 
Adopting the notation for generalized diffusion models from <d-cite key="bansal2022cold"></d-cite>, we can also consider
a forward process operator, $$D$$, that outputs the corrupted samples $$\mathbf{s}^{(n)} = D(\mathbf{s}^{(0)}, n)$$.

[//]: # (The step sizes are controlled by a variance schedule $$\{\beta_n \in &#40;0, 1&#41;\}_{n=1}^N$$ such that )
[//]: # (the samples are corrupted with increasing levels of noise for $$n\rightarrow N$$ and $$\mathbf{s}^{&#40;N&#41;} \sim \mathcal{N}&#40;\mathbf{0}, \mathbf{I}&#41;$$.)

[//]: # ($$)
[//]: # (\begin{equation*} )
[//]: # (q&#40;\mathbf{s}^{&#40;n&#41;} \vert \mathbf{s}^{&#40;n-1&#41;}&#41; = \mathcal{N}&#40;\mathbf{s}^{&#40;n&#41;}; \sqrt{1 - \beta_n} \mathbf{s}^{&#40;n-1&#41;}, \beta_n\mathbf{I}&#41; \quad )
[//]: # (q&#40;\mathbf{s}^{&#40;1:N&#41;} \vert \mathbf{s}^{&#40;0&#41;}&#41; = \prod^N_{n=1} q&#40;\mathbf{s}^{&#40;n&#41;} \vert \mathbf{s}^{&#40;n-1&#41;}&#41;)
[//]: # (\end{equation*})
[//]: # ($$)

<div class='l-body'>
<img class="img-fluid" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/noise-diagram-gaussian.png">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px;"> Graphical model for a standard diffusion model.</figcaption>
</div>

[//]: # (Adopting the notation from <d-cite key="bansal2022cold"></d-cite> for generalized diffusion models, we can also consider)
[//]: # (a forward process operator, $$D$$, that outputs the corrupted samples $$\mathbf{s}^{&#40;n&#41;} = D&#40;\mathbf{s}^{&#40;0&#41;}, n&#41;$$ )
[//]: # (for increasing degrees of corruption $$n\in\{1,\dots, N\}$$.)

[//]: # (A denoising network $$R_\theta$$, parameterized by $$\theta$$, is trained to restore $$\mathbf{s}^{&#40;0&#41;}$$,)
[//]: # (i.e. such that $$R_\theta&#40;\mathbf{s}^{&#40;n&#41;}, n&#41; \approx \mathbf{s}^{&#40;0&#41;}$$. )
[//]: # (For dynamics forecasting, the diffusion model can be conditioned on the initial conditions by considering )
[//]: # ($$R_\theta&#40;\mathbf{s}^{&#40;n&#41;}, \mathbf{x}_{t}, n&#41;$$, and trained to minimize the objective)
[//]: # ()
[//]: # ($$)
[//]: # (\begin{equation})
[//]: # (    \min_\theta )
[//]: # (    \mathbb{E}_{n \sim \mathcal{U}[\![1, N]\!], \mathbf{x}_{t}, \mathbf{s}^{&#40;0&#41;}\sim \mathcal{X}})
[//]: # (    \left[)
[//]: # (    \|R_\theta&#40;D&#40;\mathbf{s}^{&#40;0&#41;}, n&#41;, \mathbf{x}_{t}, n&#41; - \mathbf{s}^{&#40;0&#41;}\|^2)
[//]: # (    \right],)
[//]: # (\label{eq:diffusionmodels})
[//]: # (\end{equation})
[//]: # ($$)
[//]: # ()
[//]: # (where $$\mathcal{U}[\![1, N]\!]$$ denotes the uniform distribution over the integers $$\{1, \ldots, N\}$$ and)
[//]: # ($$\mathbf{s}^{&#40;0&#41;}$$ is the forecasting target<d-footnote>In practice, $R_\theta$ can also be trained to predict the Gaussian noise that has )
[//]: # (been added to the data sample using a score matching objective <d-cite key="ho2020ddpm"></d-cite>.</d-footnote>.)
[//]: # (Adopting the common approach of video diffusion models<d-cite key="voleti2022mcvd, ho2022videodiffusion, yang2022diffusion, singer2022makeavideo, ho2022imagenvideo, harvey2022flexiblevideos"></d-cite>, )
[//]: # (we train our diffusion model baselines to predict multiple steps, i.e. )
[//]: # ($$\mathbf{s}^{&#40;0&#41;} = \mathbf{x}_{t+1:t+h}$$<d-footnote>A single-step training approach $\mathbf{s}^{&#40;0&#41;} = \mathbf{x}_{t+1}$ )
[//]: # (would be possible too. However, it is has been established that multi-step training aids inference rollout performance and stability <d-cite key="weyn2019canmachines, ravuri2021skilful, brandstetter2022message"></d-cite>.)
[//]: # (Moreover, autoregressive single-step forecasting with a standard diffusion model would be extremely time-consuming during inference time.</d-footnote>.)


[//]: # (------------------------------------------- DYffusion -------------------------------------------------)
[//]: # (Make heading smaller than normal ## heading)
## DYffusion: Dynamics-informed Diffusion Model
[//]: # (To make the heading smaller, you need to edit the css 

The key innovation of our framework, DYffusion, is a reimagining of the diffusion processes to more naturally model 
spatiotemporal sequences, $$\mathbf{x}_{t:t+h}$$.
Specifically, we design the reverse (forward) process to step forward (backward) in time 
so that our diffusion model emulates the temporal dynamics in 
the data<d-footnote>Similarly to<d-cite key="song2021ddim, bansal2022cold"></d-cite>, 
our forward and reverse processes cease to represent actual "diffusion" processes. 
Differently to all prior work, our processes are _not_ based on data corruption or restoration.</d-footnote>.

<div class='l-body'>
<img class="img-fluid" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/noise-diagram-dyffusion.png">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">Graphical model for DYffusion. </figcaption>
</div>

Implementation-wise, we replace the standard denoising network, $$R_\theta$$, with a deterministic forecaster network, $$F_\theta$$.
Because we do not have a closed-form expression for the forward process, we also need to learn it from data
by replacing the standard forward process operator, $$D$$, with a stochastic interpolator network $$\mathcal{I}_\phi$$.
Intermediate steps in DYffusion's reverse process can be reused as forecasts for actual timesteps.
Another benefit of our approach is that the reverse process is initialized with the initial conditions of the dynamics 
and operates in observation space at all times. 
In contrast, a standard diffusion model is designed for unconditional generation, and reversing from white noise requires more diffusion steps. 

[//]: # (For conditional prediction tasks such as forecasting, DYffusion emerges as a much more natural method that is well aligned with the task at hand.)

### Training DYffusion
We propose to learn the forward and reverse process in two separate stages:

#### Temporal interpolation as a forward process

To learn our proposed temporal forward process,
we train a time-conditioned network $$\mathcal{I}_\phi$$ to interpolate between snapshots of data. 
Given a horizon $$h$$, we train the interpolator net so that 
$$\mathcal{I}_\phi(\mathbf{x}_t, \mathbf{x}_{t+h}, i) \approx \mathbf{x}_{t+i}$$ for $$i \in \{1, \ldots, h-1\}$$ using the objective:

$$
\begin{equation}
    \min_\phi 
        \mathbb{E}_{i \sim \mathcal{U}[\![1, h-1]\!],  \mathbf{x}_{t, t+i, t+h} \sim \mathcal{X}}
        \left[\|
            \mathcal{I}_\phi(\mathbf{x}_t, \mathbf{x}_{t+h}, i) - \mathbf{x}_{t+i}
        \|^2 \right].
\label{eq:interpolation}
\end{equation}
$$

Interpolation is an easier task than forecasting, and we can use the resulting interpolator
for temporal super-resolution during inference to interpolate beyond the temporal resolution of the data.
That is, the time input can be continuous, with $$i \in (0, h-1)$$. 
It is crucial for the interpolator, $$\mathcal{I}_\phi$$,
to _produce stochastic outputs_ within DYffusion so that its forward process is stochastic, and it can generate probabilistic forecasts at inference time.
We enable this using Monte Carlo dropout <d-cite key="gal2016dropout"></d-cite> at inference time.


#### Forecasting as a reverse process

In the second stage, we train a forecaster network $$F_\theta$$ to forecast $$\mathbf{x}_{t+h}$$
such that $$F_\theta(\mathcal{I}_\phi(\mathbf{x}_{t}, \mathbf{x}_{t+h}, i \vert \xi), i)\approx \mathbf{x}_{t+h}$$
for $$i \in S =[i_n]_{n=0}^{N-1}$$, where $$S$$ denotes a schedule coupling the diffusion step to the interpolation timestep. 
The interpolator network, $$\mathcal{I}$$, is frozen with inference stochasticity enabled,
represented by the random variable $$\xi$$. 
In our experiments, $$\xi$$ stands for the randomly dropped out weights of the neural network and is omitted henceforth for clarity.
Specifically, we seek to optimize the objective

$$
\begin{equation}
    \min_\theta 
        \mathbb{E}_{n \sim \mathcal{U}[\![0, N-1]\!], \mathbf{x}_{t, t+h}\sim \mathcal{X}}
        \left[\|
            F_\theta(\mathcal{I}_\phi(\mathbf{x}_{t}, \mathbf{x}_{t+h}, i_n \vert \xi), i_n) - \mathbf{x}_{t+h}
        \|^2 \right].
\label{eq:forecaster}
\end{equation}
$$

To include the setting where $$F_\theta$$ learns to forecast the initial conditions, 
we define $$i_0 := 0$$ and $$\mathcal{I}_\phi(\mathbf{x}_{t}, \cdot, i_0) := \mathbf{x}_t$$.
In the simplest case, the forecaster net is supervised by all timesteps given
by the temporal resolution of the training data. That is, $$N=h$$ and $$S = [j]_{j=0}^{h-1}$$. 
Generally, the schedule should satisfy $$0 = i_0 < i_n < i_m < h$$ for $$0 < n < m \leq N-1$$.

[//]: # (As the time condition to our diffusion backbone is $$i_n$$ instead of $$n$$,)
[//]: # (we can choose _any_ diffusion-dynamics schedule during training or inference )
[//]: # (and even use $$F_\theta$$ for unseen timesteps.  )

[//]: # (Make algo image only be 75% of the page width)
<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/algo-training.png" width="75%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">DYffusion's two-stage training procedure is summarized in the algorithm above. </figcaption>
</div>

[//]: # (Because the interpolator $$\mathcal{I}_\phi$$ is frozen in the second stage,)
[//]: # (the imperfect forecasts  $$\hat{\mathbf{x}}_{t+h} = F_\theta&#40;\mathcal{I}_\phi&#40;\mathbf{x}_{t}, \mathbf{x}_{t+h}, i_n&#41;, i_n&#41;$$)
[//]: # (may degrade accuracy when used during sequential sampling. )
[//]: # (To handle this, we introduce an optional one-step look-ahead loss term )
[//]: # ($$\|  F_\theta&#40;\mathcal{I}_\phi&#40;\mathbf{x}_{t}, \hat{\mathbf{x}}_{t+h}, i_{n+1}&#41;, i_{n+1}&#41; - \mathbf{x}_{t+h} \|^2$$ )
[//]: # (whenever $$n+1 < N$$ and weight the two loss terms equally. )
[//]: # (Additionally, providing a clean or noised form of the initial conditions $$\mathbf{x}_t$$ as an additional input to)
[//]: # (the forecaster net can improve performance. )
[//]: # (These additional tricks are discussed in more details in the Appendix B of <a href="https://arxiv.org/abs/2306.01984">our paper</a>.)

### Sampling from DYffusion

Our above design for the forward and reverse processes of DYffusion, implies the following generative process:
$$
\begin{equation}
    p_\theta(\mathbf{s}^{(n+1)} | \mathbf{s}^{(n)}, \mathbf{x}_t) = 
    \begin{cases}
        F_\theta(\mathbf{s}^{(n)}, i_{n})  & \text{if} \ n = N-1 \\
        \mathcal{I}_\phi(\mathbf{x}_t, F_\theta(\mathbf{s}^{(n)}, i_n), i_{n+1}) & \text{otherwise,}
    \end{cases} 
    \label{eq:new-reverse}
\end{equation}
$$

where $$\mathbf{s}^{(0)}=\mathbf{x}_t$$ and $$\mathbf{s}^{(n)}\approx\mathbf{x}_{t+i_n}$$ 
correspond to the initial conditions and predictions of intermediate steps, respectively.
In our formulations, we reverse the diffusion step indexing to align with the temporal indexing of the data. 
That is, $$n=0$$ refers to the start of the reverse process, 
while $$n=N$$ refers to the final output of the reverse process with $$\mathbf{s}^{(N)}\approx\mathbf{x}_{t+h}$$.
Our reverse process steps forward in time, in contrast to the mapping from noise to data in standard diffusion models. 
As a result, DYffusion should require fewer diffusion steps and data.

DYffusion follows the generalized diffusion model framework.
Thus, we can use existing diffusion model sampling methods for inference.
In our experiments, we adapt the sampling algorithm from <d-cite key="bansal2022cold"></d-cite> to our setting as shown below.

[//]: # (Make algo image only be 75% of the page width)
<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/algo-sampling-cold.png" width="75%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">Sampling algorithm for DYffusion. </figcaption>
</div>

[//]: # (In Appendix~\ref{appendix:ode-cold-is-better}, we also discuss a simpler but less performant sampling algorithm.)
During the sampling process, our method essentially alternates between forecasting and interpolation, 
as illustrated in the figure below.
$$R_\theta$$ always predicts the last timestep, $$\mathbf{x}_{t+h}$$, 
but iteratively improves those forecasts as the reverse process comes closer in time to $$t+h$$.
This is analogous to the iterative denoising of the "clean" data in standard diffusion models.
This motivates line 6 of Alg. 2, where the final forecast of $$\mathbf{x}_{t+h}$$ can be used to
fine-tune intermediate predictions or to increase the temporal resolution of the forecast.

<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/sampling-unrolled.png" width="75%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
During sampling, DYffusion essentially alternates between forecasting and interpolation, following Alg. 2. 
In this example, the sampling trajectory follows a simple schedule of going through all integer timesteps that precede the horizon of $h=4$,
with the number of diffusion steps $N=h$. 
The output of the last diffusion step is used as the final forecast for $\hat\mathbf{x}_4$.
The <span style="color:black;font-weight:bold">black</span> lines represent forecasts by the forecaster network, $F_\theta$.
The first forecast is based on the initial conditions, $\mathbf{x}_0$.
The <span style="color:blue;font-weight:bold">blue</span> lines represent the subsequent temporal interpolations performed by the interpolator network, $\mathcal{I}_\phi$.
</figcaption>
</div>

[//]: # (DYffusion can be applied autoregressively to forecast even longer rollouts beyond the training horizon, )
[//]: # (as demonstrated by our Navier-Stokes and spring mesh experiments.)

### Memory footprint

During training, DYffusion only requires $$\mathbf{x}_t$$ and $$\mathbf{x}_{t+h}$$ (plus $$\mathbf{x}_{t+i}$$ during the first interpolation stage),
resulting in a _constant memory footprint as a function of_ $$h$$. 
In contrast, direct multi-step prediction models including video diffusion models or (autoregressive) multi-step loss approaches require 
$$\mathbf{x}_{t:t+h}$$ to compute the loss. 
This means that these models must fit $$h+1$$ timesteps of data into memory (and may need to compute gradients recursively through them),
which scales poorly with the training horizon $$h$$. 
Therefore, many are limited to predicting a small number of frames or snapshots.
For example, our main video diffusion model baseline, MCVD, trains on a maximum of 5 video frames due to GPU memory constraints <d-cite key="voleti2022mcvd"></d-cite>.

<div class='l-body'>
<img class="img-fluid" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/dyffusion-vs-video-diffusion-diagram.png">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">On the top row, we illustrate the direct application of a video diffusion model to dynamics forecasting for a horizon of $h=3$.
    On the bottom row, DYffusion generates continuous-time probabilistic forecasts for $\mathbf{x}_{t+1:t+h}$, given the initial conditions, $\mathbf{x}_t$.
    Our approach operates in the observation space at all times and does not need to model high-dimensional videos at each diffusion state.</figcaption>
</div>

## Experimental Setup

#### Datasets

We evaluate our method and baselines on three different datasets:
1. **Sea Surface Temperatures (SST):** a new dataset based on NOAA OISSTv2<d-cite key="huang2021oisstv2"></d-cite>, which 
comes at a daily time-scale. Similarly to <d-cite key="de2018physicalsstbaseline, wang2022metalearning"></d-cite>, 
we train our models on regional patches which increases the available 
data<d-footnote>Here, we choose 11 boxes of $60$ latitude $\times 60$ longitude resolution in the eastern tropical Pacific Ocean.
Unlike the data based on the NEMO dataset in <d-cite key="de2018physicalsstbaseline, wang2022metalearning"></d-cite>,
we choose OISSTv2 as our SST dataset because it contains more data (although it has a lower spatial resolution of $1/4^\circ$ compared to $1/12^\circ$ of NEMO).</d-footnote>.
We train, validate, and test all models for the years 1982-2019, 2020, and 2021, respectively.
2. **Navier-Stokes** flow benchmark dataset from <d-cite key="otness21nnbenchmark"></d-cite>, which consists of a
$$221\times42$$ grid. Each trajectory contains four randomly generated circular obstacles that block the flow.
The channels consist of the $$x$$ and $$y$$ velocities as well as a pressure field and the viscosity is $$1e\text{-}3$$.
Boundary conditions and obstacle masks are given as additional inputs to all models.
3. **Spring Mesh** benchmark dataset from <d-cite key="otness21nnbenchmark"></d-cite>. It represents a $$10\times10$$ grid of
particles connected by springs, each with mass 1. The channels consist of two position and momentum fields each.

We follow the official train, validation, and test splits from <d-cite key="otness21nnbenchmark"></d-cite> for the Navier-Stokes and spring mesh datasets, 
always using the full training set for training.

#### Baselines

We compare our method against both direct applications of standard diffusion models to dynamics forecasting and
methods to ensemble the "barebone" backbone network of each dataset. The network operating in "barebone" form means
that there is no involvement of diffusion. 
We use the following baselines:
- **DDPM**<d-cite key="ho2020ddpm"></d-cite>: We train it as a multi-step (video-like problem) conditional diffusion model.
- **MCVD**<d-cite key="voleti2022mcvd"></d-cite>: A state-of-the-art conditional video diffusion model<d-footnote>We train MCVD in "concat" mode, which in their experiments performed best.</d-footnote>.
- **Dropout**<d-cite key="gal2016dropout"></d-cite>: Ensemble multi-step forecasting of the barebone backbone network based on enabling dropout at inference time.
- **Perturbation**<d-cite key="pathak2022fourcastnet"></d-cite>: Ensemble multi-step forecasting with the barebone backbone network based on random perturbations of the initial conditions with a fixed variance.
- Official **deterministic** baselines from<d-cite key="otness21nnbenchmark"></d-cite> for 
the Navier-Stokes and spring mesh datasets <d-footnote>Due to their deterministic nature, we exclude these baselines from our main probabilistic benchmarks.</d-footnote>.

MCVD and the multi-step DDPM predict the timesteps $$\mathbf{x}_{t+1:t+h}$$ based on $$\mathbf{x}_{t}$$.
The barebone backbone network baselines are time-conditioned forecasters trained on the multi-step objective 
$$\mathbb{E}_{i \sim \mathcal{U}[\![1, h]\!], \mathbf{x}_{t, t+i}\sim \mathcal{X}} 
    \| F_\theta(\mathbf{x}_{t}, i) - \mathbf{x}_{t+i}\|^2$$ 
from scratch<d-footnote>We found it to perform very similarly to predicting all $h$ 
horizon timesteps at once in a single forward pass, i.e. on the 
objective $\mathbb{E}_{\mathbf{x}_{t:t+h}\sim \mathcal{X}} \| F_\theta(\mathbf{x}_{t}) - \mathbf{x}_{t+1:t+h}\|^2$</d-footnote>.

[//]: # (See Appendix D.2 of <a href="https://arxiv.org/abs/2306.01984">our paper</a> for more details of the implementation.)

#### Neural network architectures

For a given dataset, we use the _same backbone architecture_ for all baselines as well as for both the interpolation and forecaster networks in DYffusion.
For the SST dataset, we use a <a href="https://github.com/lucidrains/denoising-diffusion-pytorch/blob/main/denoising_diffusion_pytorch/denoising_diffusion_pytorch.py">popular UNet architecture</a> designed for diffusion models.
For the Navier-Stokes and spring mesh datasets, we use the UNet and CNN from the original benchmark paper <d-cite key="otness21nnbenchmark"></d-cite>, respectively.
The UNet and CNN models from <d-cite key="otness21nnbenchmark"></d-cite> are extended by the sine/cosine-based featurization module of the SST UNet to embed the diffusion step or dynamical timestep.

#### Evaluation metrics

We evaluate the models by generating an M-member ensemble (i.e. M samples are drawn per batch element), where
we use M=20 for validation and M=50 for testing. 
As metrics, we use the Continuous Ranked Probability Score (CRPS) <d-cite key="matheson1976crps"></d-cite>,
the mean squared error (MSE), and the spread-skill ratio (SSR).
The CRPS is a proper scoring rule and a popular metric in the probabilistic forecasting
literature<d-cite key="gneiting2014Probabilistic, bezenac2020normalizing, Rasul2021AutoregressiveDD, rasp2018postprocessing, scher2021ensemble"></d-cite>.
The MSE is computed on the ensemble mean prediction. 
The SSR is defined as the ratio of the square root of the ensemble variance to the corresponding ensemble mean RMSE.
It serves as a measure of the reliability of the ensemble, where values smaller than 1 indicate 
underdispersion<d-footnote>That is, the probabilistic forecast is overconfident and fails to model the full uncertainty of the forecast</d-footnote> 
and larger values overdispersion<d-cite key="fortin2014ssr, garg2022weatherbenchprob"></d-cite>.
On the Navier-Stokes and spring mesh datasets, models are evaluated by autogressively forecasting the full test trajectories of length 64 and 804, respectively.
For the SST dataset, all models are evaluated on forecasts of up to 7 days<d-footnote>We do not explore more long-term SST forecasts because the chaotic nature of the system, and the fact that we only use regional patches, inherently limits predictability.</d-footnote>.


## Results
### Quantitative results
We present the time-averaged metrics for the SST and Navier-Stokes dataset in the table below.
DYffusion performs best on the Navier-Stokes dataset, while coming in a close second on the SST dataset after MCVD, in terms of CRPS.
Since MCVD uses 1000 diffusion steps, 
it is slower to sample from at inference time than from DYffusion, which is trained with at most 35 diffusion steps.
The DDPM model for the SST dataset is fairly efficient because it only uses 5 diffusion steps but lags in terms of performance.

<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/results-table-main.png" width="95%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
Results for sea surface temperature forecasting of 1 to 7 days ahead, and Navier-Stokes
flow full trajectory forecasting of 64 timesteps.
For SST, all models are trained on forecasting $h=7$ timesteps. The time column represents the time needed to forecast all 7 timesteps for a single batch. 
For Navier-Stokes, Perturbation, Dropout, and DYffusion are trained on a horizon of $h=16$. 
MCVD and DDPM are trained on $h=4$ and $h=1$, respectively, as we could not successfully train them using larger horizons.
<span style="font-weight:bold">Bold</span> indicates best, <span style="color:blue">blue</span> second best. 
For CRPS and MSE, lower is better. For SSR, closer to 1 is better. Numbers are averaged out over the evaluation horizon.
</figcaption>
</div>

Thanks to the dynamics-informed and memory-efficient nature of DYffusion, we can scale our framework to long horizons.
On the spring mesh dataset, we train with a horizon of 134 and evaluate the models on trajectories of 804 time steps.
Our method beats the Dropout baseline, with a larger margin on the out-of-distribution test dataset.
Despite several attempts with varying hyperparameter configurations neither the DDPM nor the MCVD diffusion model converged on this dataset.

<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/results-table-spring-mesh.png" width="95%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
Spring Mesh results. Both methods are trained on a horizon of $h = 134$ timesteps and
evaluated how well they forecast the full test trajectories of 804 steps. 
For CRPS and MSE, lower is better. For SSR, closer to 1 is better. Numbers are averaged out over the evaluation horizon.
</figcaption>
</div>

The reported MSE scores above, using the same CNN architecture, 
are significantly better than the ones reported for the official CNN baselines in Fig. 8 of <d-cite key="otness21nnbenchmark"></d-cite>,
where the deterministic CNN diverged or attained a very poor MSE. 
This is likely because our models are trained to forecast multiple timesteps, 
while the models from <d-cite key="otness21nnbenchmark"></d-cite> are trained to forecast the next timestep only.
As a result, the training objective significantly deviates from the evaluation procedure,
which was already noted as a limitation of the benchmark baselines in <d-cite key="otness21nnbenchmark"></d-cite>.
This effect is also found for the Navier-Stokes dataset to a lower extent, as demonstrated in the figures below.

<div class="row l-body">
    <div class="col-sm">
      <img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/mse-vs-time-navier-stokes.png">
   <figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">Navier-Stokes</figcaption>
    </div>
    <div class="col-sm">
  <img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/mse-vs-time-spring-mesh.png">
   <figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">Spring Mesh</figcaption>
    </div>
    <!--- add joint caption here --->
    <figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
        Comparison against single-step deterministic baselines from <d-cite key="otness21nnbenchmark"></d-cite>.
        We plot the MSE as a function of the rollout time step.
        For spring mesh, we plot each of the three models trained with a different random seed separately due to the high variance.
</figcaption>
</div>

### Qualitative results

Long-range forecasts of ML models often suffer from blurriness or might even diverge when using autoregressive models.
In the video below, we show a complete Navier-Stokes test trajectory forecasted by DYffusion and the best baseline, Dropout, as well as the corresponding ground truth.
Our method can reproduce the true dynamics over the full trajectory and does so better than the baseline, 
especially for fine-scale patterns such as the tails of the flow after the right-most obstacle.

[//]: # (Embed mp4 video)

<div class='l-body' align="center">
<video width="100%" controls>
  <source src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/ls9vw31m-kwy9mak6-5fps.mp4" type="video/mp4">
</video>
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
Exemplary samples from DYffusion and the best baseline, Dropout, as well as the corresponding ground truth from a complete Navier-Stokes trajectory forecast. 
</figcaption>
</div>

### Temporal super-resolution and sample variability

Motivated by the continuous-time nature of DYffusion, we aim to study in this experiment whether it is possible to forecast
skillfully beyond the resolution given by the data. 
Here, we forecast the same Navier-Stokes trajectory shown in the video above but at $$8\times$$ resolution. 
That is, DYffusion forecasts 512 timesteps instead of 64 in total.
This behavior can be achieved by either changing the sampling trajectory $$[i_n]_{n=0}^{N-1}$$ or 
by including additional output timesteps, $$J$$, for the refinement step of line 6 in Alg. 2.
In the video below, we choose to do the latter and find the 5 sampled forecasts to be visibly pleasing and temporally consistent with the ground truth.

[//]: # (Embed mp4 video)

<div class='l-body' align="center">
<video width="100%" controls>
  <source src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/yivdhhzu-trajectory4-0.125res-timeDependentTruthBoundary-5samples-5fps.mp4" type="video/mp4">
</video>
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
$8\times$ temporal super-resolution of a Navier-Stokes trajectory with DYffusion. 
The ground truth is frozen in-between the original timesteps. Five distinct samples are shown.
</figcaption>
</div>

Note that we hope that our probabilistic forecasting model can capture any of the possible,
uncertain futures instead of forecasting their mean, as a deterministic model would do. 
As a result, some long-term rollout samples are expected to deviate from the ground truth. 
For example, see the velocity at _t_=3.70 in the video above.
It is reassuring that DYffusion's samples show sufficient variation, but also cover the ground truth quite well (sample 1).
This advantage is also reflected quantitatively in the spread-skill ratio (SSR) metric, where DYffusion 
consistently reached values close to 1.

### Iterative refinement of forecasts 

DYffusion's forecaster network repeatedly predicts the same timestep, $$t+h$$, during sampling.
Thus, we need to verify that these forecasts, 
$$\hat{\mathbf{x}}_{t+h} = F_\theta(\mathbf{x}_{t+i_n}, i_n)$$, tend to improve throughout the course of the reverse process, 
i.e. as $$n\rightarrow N$$ and $$\mathbf{x}_{t+i_n}\rightarrow\mathbf{x}_{t+h}$$.
Below we show that this is indeed the case for the Navier-Stokes dataset. 
Generally, we find that this observation tends to hold especially for the probabilistic metrics, CRPS and SSR, 
while the trend is less clear for the MSE across all datasets (see Fig. 7 of <a href="https://arxiv.org/abs/2306.01984">our paper</a>).

<div class='l-body' align="center">
<img class="img-fluid rounded" src="{{ site.baseurl }}/assets/img/2023-12-dyffusion/diffusion-step-vs-metric-navier-stokes.png" width="100%">
<figcaption style="text-align: center; margin-top: 10px; margin-bottom: 10px">
DYffusion's forecaster network iteratively improves its forecasts during sampling.
</figcaption>
</div>


## Conclusion

[//]: # (Our study presents the first comprehensive evaluation)
[//]: # (of diffusion models for the task of spatiotemporal forecasting.)

DYffusion is the first diffusion model that relies on task-informed forward and reverse processes.
Other existing diffusion models, albeit more general, use data corruption-based processes. 
Thus, our work provides a new perspective on designing a capable diffusion model, 
and we hope that it will lead to a whole family of task-informed diffusion models.

[//]: # (We are )
If you have any application that you think could benefit from DYffusion, or build on top of it, we would love to hear from you!

For more details, please **_check out our [NeurIPS 2023 paper](https://arxiv.org/abs/2306.01984),
and our [code on GitHub](https://github.com/Rose-STL-Lab/dyffusion)_**.
