# RFIL: Raw Filecoin

Initiated by **rawfilecoin@gmail.com**

**Your Support Needed**: To contribute and support this project, please refer to the [Support Our Project](#join-our-project) section below for details.


## Overview

Raw Filecoin (RFIL) is a token distributed to miners on the Filecoin network, aligning with the Filecoin whitepaper's vision. Rewards are allocated based on actual storage contributions, focusing on RawBytes rather than QAP. RFIL is running on FEVM, with voluntary participation from miners who can claim daily rewards.

**Launch Date:**  `Jan. 31st 2024`

**Contract Address:**  `0xa9f903a1e92e43d048a718880882fc7861558526` or `f02952369`


## Goals

- Restoring the original vision of Filecoin.
- Compensating CC miners without distinction between DC and CC sectors for RFIL rewards.
- Implementing the system in the simplest manner.

## Tokenomics

- Adopts Filecoin's economic model described in its whitepaper.
- Total supply: 2 billion tokens.
- Distribution: Halving every six years, starting from the contract launch.
- Allocation: 100% fair launch, 100% dedicated to mining, with no reserves for the project or any team, no future issurance.

## Mining Rules

- Miners can claim rewards once daily through any Controlling address or a designated bound address.
- Rewards are sent to the request sender's account.
- Conditions:
  - A minimum block height difference of 2800 is required between reward claims
  - Miner's RawbytesPower must exceed the minimum computation power defined by Filecoin (currently 10TiB).

## Reward Calculation

### Overall Formula

$$
Reward =
\begin{cases}
0 & \text{if } curHeight - PrevHeight < 2800 \\
todayReward \times  \min( \frac{minerRawPower}{totalRawPower} \times \frac{\min\left(2880, curHeight - prevHeight\right)}{2880} \times AdjustFactor, 1) & \text{if } curHeight - PrevHeight \geq 2800
\end{cases}
$$

Factors:

- `todayReward`: Calculated daily based on the remaining supply and the six-year halving schedule.
- `minerRawPower/totalRawPower`: Miner's proportion of total network rawbytes power.
- `curHeight` and `prevHeight`: Current and previous block heights of the miner's reward claim.
- `AdjustFactor`: A coefficient adjusted based on daily total reward distribution, ensuring alignment with theoretical release values.

Notes:
- A claim must be more than 2800 blocks beyond the last successful claim to be eligible for a reward.
- If the span between the current and the previous claims falls between 2800 and 2880 blocks, a corresponding fraction of the daily reward is allocated.
- For calculation purposes, if the gap between the current and previous claims surpasses 2880 blocks, it should be truncated to 2880.
- The daily reward allocated to any miner shall not surpass the designated daily reward for that day.



### todayReward

`todayReward` is based on the remaining supply (`remainingSupply`) in the reward pool and is calculated each time when minting according to a six-year halving schedule.

- Initial value of the remaining supply:
  - `RemainingSupply` = `Total Supply` = 2,000,000,000
- After each reward distribution:
  - `RemainingSupply -= reward`
- The release follows a six-year halving schedule, modeled after the radioactive decay (exponential decay model).

Based on the exponential decal model, we have:

<div align="center">

$$
halvingDays = 6 years = 6 * 365 days = 2190 days
$$

$$
todayReward = RemainingSupply \times \left(1 - 0.5^{\frac{1}{2190}}\right)
$$

$$
todayReward = RemainingSupply \times  0.00031645547929815
$$

</div>

Please note that `todayReward` is not calculated daily in the smart contract, but is calculated each time a legitimate request to claim Reward is received. Since we adopt a proportional release mothod, the released value is essentially consistent with the theoretical value.

### Estimated Release Volume and Remaining Supply for the First Day of the First Seven Years

| Year | Remaining Supply on the First Day | Release Amount on the First Day |
|------|-----------------------------------|---------------------------------|
| 1    | 2,000,000,000                     | 632,911                         |
| 2    | 1,781,797,436                     | 563,860                         |
| 3    | 1,587,401,052                     | 502,342                         |
| 4    | 1,414,213,562                     | 447,536                         |
| 5    | 1,259,921,050                     | 398,709                         |
| 6    | 1,122,462,048                     | 355,209                         |
| 7    | 1,000,000,000                     | 316,455                         |


### AdjustFactor Renew

`AdjustFactor` is a variable that ensures the daily distribution of rewards does not deviate significantly from the theoretical model. It reflects the ratio between the theoretical daily reward distribution and the actual on-chain daily reward distribution.

The initial setting for `AdjustFactor` is established at **100**. This initial high value is predicated on the expectation that there will be a gradual uptake in reward claims by the majority of miners following the contract's inception. Early claimants are effectively incentivized with higher rewards due to this elevated AdjustFactor. Nonetheless, the `AdjustFactor` is dynamically adjusted to ensure that the reward distribution remains as consistent as possible. Rapid adjustments to the `AdjustFactor` are feasible to accurately mirror the actual ratio of rawbytes power claiming the rewards very soon.

To mitigate significant swings in the AdjustFactor, its rate of change is capped to either doubling or halving with each adjustment. The AdjustFactor is recalibrated prior to distributing the Reward in the course of processing a mint request. In instances where there has been no minting activity over the past day, the AdjustFactor is set to doubled to prevent division by zero.

To safeguard against any overflow, the AdjustFactor is constrained within a defined range: it is capped at a maximum of 10,000 and floored at a minimum of 0.01. Therefore, the AdjustFactor is consistently maintained within the [0.01, 10,000] boundary.

**Calculation:** 

$$
onedayReleasedReward = \sum_{curHeight-2880}^{curHeight} \ ReleasedReward
$$

Pseudo code (executed before each reward minting):
```golang
    if (oneDayReleaseReward == 0) {
      AdjustFactor *= 2
    } else {
      r = todayReward / onedayReleasedReward
      if (r > 2) then r = 2
      if (r < 0.5) then r = 0.5
      AdjustFactor *= r
    }
    if (AdjustFactor > 10000) AdjustFactor = 10000;
    if (AdjustFactor < 0.01) AdjustFactor = 0.01
```

## Donate
Raw Filecoin is freely available for mining, yet donations are welcomed to support the project's anonymous designer and implementer. Generous contributions will be utilized for marketing efforts, enhancing the Filecoin ecosystem, and assisting with the listing of RFIL on various exchanges. 

**Filecoin f1 Address**: `f1dukhljfxep7siqtkcmfnweqzllc52iphp4dlzzq`

**Ethereum Address**:    `0xB8F30cAF96025b2091191dc746c6d7E41Ce89eDF`

**Filecoin f4 Address**: `f410fxdzqzl4wajnsbeizdxdunrwx4qoorhw7mpktrki`


## Join Our Project

### Be a Part of Our Open-Source Journey

Our project, at its core, is a decentralized application (DApp) driven by smart contracts. However, we believe in the power of community and collaboration to expand its potential beyond just code. We are actively seeking passionate individuals who are excited about decentralizatio and wish to contribute to Filecoin's original Vision. Whether you're a designer, marketer, writer, or web developer, your skills and contributions can make a significant impact.

### Areas We Need Your Help

- **Icon and Graphic Design**: Creativity is key! We're looking for designers to help create engaging icons and graphics for RawFilecoin.
- **Slogan and Branding**: Got a way with words? Help us coin catchy slogans and branding ideas that resonate with our audience.
- **Marketing and Outreach**: Spread the word! If you have skills in digital marketing, SEO, or social media management, join us in promoting RawFilecoin.
- **Web Development**: We need web developers to help build a user-friendly website for RawFilecoin, enhancing user experience and interface.
- **Content Creation**: If writing is your forte, contribute by crafting informative and engaging articles or blog posts about RawFilecoin.

### How to Get Involved

Getting involved is easy! Here’s how you can start:

1. **Check Out Our Repository**: Visit our GitHub repository to get an overview of our project.
2. **Reach Out**: If you’re interested in contributing, open an issue in our repository or send us an email detailing how you wish to help.
3. **Collaborate and Create**: Once onboard, collaborate with our team and contribute towards making a difference in the decentralized Filecoin world.

Your contributions, big or small, are invaluable to us. By joining Raw Filecoin, you’re not only helping us grow, but you’re also becoming part of an exciting journey in the world of Real Filecoin.

[Join us](mailto:rawfilecoin@gmail.com) today, and let’s build something amazing together!
