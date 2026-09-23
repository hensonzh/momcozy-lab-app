const imgAssetCozymateAvatar = "https://www.figma.com/api/mcp/asset/d4e3b1a9-891d-41ed-8a18-285edae72f66.png";
const imgIconTileExpertSupport = "https://www.figma.com/api/mcp/asset/0cc78d06-6c3d-4c2f-bae2-3f5953b793ab.png";
const imgAvatarCozymateNav = "https://www.figma.com/api/mcp/asset/8ec3bba3-d991-4532-9a7d-803d16bc267e.png";
const imgDecorationAiSparkle = "https://www.figma.com/api/mcp/asset/8efed789-ca58-4692-a63c-e28860c8cbe4.svg";
const imgDecorationAiBlushGlow = "https://www.figma.com/api/mcp/asset/41e80dde-4037-44fc-8985-4116784ab4d0.svg";
const imgDecorationAiLilacGlow = "https://www.figma.com/api/mcp/asset/d8956082-5e59-4c13-b653-f6c3ebdf6639.svg";
const imgDecorationLactationDroplet = "https://www.figma.com/api/mcp/asset/b61947e9-01a6-434d-8f8c-1fb1303febab.svg";
const imgDecorationBodyRecoverySoftDot = "https://www.figma.com/api/mcp/asset/5d8b1271-1ad9-4ce1-946d-ab8ae11bba0d.svg";
const imgDecorationBodyRecoveryRing = "https://www.figma.com/api/mcp/asset/104d9a18-2ed2-4f63-9053-2c0adcd361d5.svg";
const imgDecorationBodyRecoveryGlow = "https://www.figma.com/api/mcp/asset/e25ab027-68a9-4f6e-a7bf-265224caac0c.svg";
const imgDecorationSleepCrescent = "https://www.figma.com/api/mcp/asset/4ff3b8fd-a615-438f-9c80-85f0c81e6e4f.svg";
const imgDecorationMoodWave = "https://www.figma.com/api/mcp/asset/1b520487-b583-467d-b8dc-02d03a687a38.svg";
const imgDecorationExpertSupportHalo = "https://www.figma.com/api/mcp/asset/6f127101-9454-485e-bdbb-1c09eddcac8f.svg";
const imgDecorationExpertSupportLeaves = "https://www.figma.com/api/mcp/asset/66383066-d56b-4329-9251-ec9fda1c2ff6.svg";
const imgIconExpertSupportArrow = "https://www.figma.com/api/mcp/asset/da0ba054-f91d-4f75-bd4b-fb3c0da96c01.svg";
const imgIconMe = "https://www.figma.com/api/mcp/asset/418471f8-694a-4d5d-9fb0-923ea25d5e0e.svg";
const imgIconBaby = "https://www.figma.com/api/mcp/asset/9016b8cc-42c0-4937-859a-e76203b5898f.svg";
const imgIconSchedule = "https://www.figma.com/api/mcp/asset/3de2b6e4-eec2-48dd-9a90-f007bd43f069.svg";
const imgIconMore = "https://www.figma.com/api/mcp/asset/8ef50fe4-80cc-47f8-bbb4-0ddf031c9cbf.svg";

export default function ScreenMomHomeInitial() {
  return (
    <div className="bg-[#fbf8f4] content-stretch flex flex-col gap-[14px] items-start pt-[18px] px-[16px] relative size-full" data-node-id="88:2" data-name="screen/mom-home-initial">
      <div className="[word-break:break-word] content-stretch flex h-[58px] items-center justify-between overflow-clip relative shrink-0 w-full whitespace-nowrap" data-node-id="88:3" data-name="section/header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold leading-[34px] relative shrink-0 text-[#292424] text-[20px]" data-node-id="88:4">
          下午好，Mia
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] relative shrink-0 text-[#756966] text-[12px]" data-node-id="88:5">
          产后第 21 天 · 恢复建立期
        </p>
      </div>
      <div className="bg-gradient-to-r from-[#fff3ee] h-[138px] overflow-clip relative rounded-[22px] shrink-0 to-[#ead9fb] via-[#f8f0f7] via-[48%] w-full" data-node-id="88:6" data-name="card/ai-insight">
        <div className="absolute left-[314px] size-[20px] top-[74px]" data-node-id="88:7" data-name="decoration/ai-sparkle">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiSparkle} />
        </div>
        <div className="absolute h-[92px] left-[-42px] top-[88px] w-[150px]" data-node-id="88:9" data-name="decoration/ai-blush-glow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiBlushGlow} />
        </div>
        <div className="absolute left-[270px] size-[128px] top-[-36px]" data-node-id="88:10" data-name="decoration/ai-lilac-glow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiLilacGlow} />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[18px] text-[#665b8a] text-[12px] top-[12px] w-[190px]" data-node-id="88:11">
          Cozymate · 等待你的首次记录
        </p>
        <div className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[50px] leading-[0] left-[18px] text-[#292733] text-[16px] top-[34px] w-[240px]" data-node-id="88:12">
          <p className="leading-[25px] mb-0">记录一点点，</p>
          <p className="leading-[25px]">我会更懂你的恢复状态</p>
        </div>
        <div className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[34px] leading-[0] left-[18px] text-[#706d78] text-[11px] top-[90px] w-[284px]" data-node-id="88:13">
          <p className="leading-[17px] mb-0">完成首次记录后，AI 会结合你的状态，</p>
          <p className="leading-[17px]">生成每日恢复分析与行动建议。</p>
        </div>
        <div className="absolute left-[293px] size-[50px] top-[12px]" data-node-id="88:14" data-name="asset/cozymate-avatar">
          <img alt="" className="absolute block inset-0 max-w-none size-full" height="50" src={imgAssetCozymateAvatar} width="50" />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[322px] text-[#665b8a] text-[22px] top-[101px] whitespace-nowrap" data-node-id="88:15">
          →
        </p>
      </div>
      <div className="[word-break:break-word] content-stretch flex h-[30px] items-center justify-between overflow-clip relative shrink-0 w-[361px]" data-node-id="88:16" data-name="section/lactation-header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold leading-[28px] relative shrink-0 text-[#2b2624] text-[18px] whitespace-nowrap" data-node-id="88:17">
          今日泌乳
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium leading-[18px] relative shrink-0 text-[#ab476b] text-[12px] whitespace-pre" data-node-id="88:18">{`查看记录  ›`}</p>
      </div>
      <div className="bg-gradient-to-r content-stretch flex flex-col from-[#fbece8] gap-[4px] h-[132px] items-start overflow-clip pb-[10px] pt-[12px] px-[16px] relative rounded-[22px] shrink-0 to-[#f7e5e1] w-full" data-node-id="88:19" data-name="card/lactation-empty">
        <div className="absolute h-[49px] left-[302px] top-[4px] w-[42px]" data-node-id="88:20" data-name="decoration/lactation-droplet">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationLactationDroplet} />
        </div>
        <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[29px] relative shrink-0 text-[#2e2424] text-[18px] whitespace-nowrap" data-node-id="88:22">
          待记录
        </p>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[13px] leading-[13px] left-[16px] text-[#7a6663] text-[10px] top-[104px] w-[172px]" data-node-id="88:23">
          记录后，AI 会持续判断奶量与供需趋势
        </p>
        <div className="absolute bg-[#b54f78] content-stretch flex h-[38px] items-center justify-center left-[16px] overflow-clip rounded-[19px] top-[54px] w-[329px]" data-node-id="88:24" data-name="button/record-lactation">
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Bold'] font-bold leading-[normal] relative shrink-0 text-[14px] text-white whitespace-nowrap" data-node-id="88:25">
            ＋ 记录一次泌乳
          </p>
        </div>
      </div>
      <div className="[word-break:break-word] content-stretch flex h-[32px] items-center justify-between leading-[normal] overflow-clip relative shrink-0 w-full" data-node-id="88:26" data-name="section/recovery-header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold relative shrink-0 text-[#292424] text-[18px] whitespace-nowrap" data-node-id="88:27">
          今日状态
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium relative shrink-0 text-[#a65470] text-[12px] whitespace-pre" data-node-id="88:28">{`今日完成 0/3 · 开始记录  ›`}</p>
      </div>
      <div className="h-[184px] overflow-clip relative shrink-0 w-full" data-node-id="88:29" data-name="group/recovery-status">
        <div className="absolute bg-gradient-to-r from-[#f7f1e7] h-[108px] left-0 overflow-clip rounded-[20px] to-[#f2e9db] top-0 w-[175px]" data-node-id="88:30" data-name="card/body-recovery">
          <div className="absolute left-[119px] size-[28px] top-[77px]" data-node-id="88:31" data-name="decoration/body-recovery-soft-dot">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoverySoftDot} />
          </div>
          <div className="absolute left-[137px] size-[76px] top-[53px]" data-node-id="88:32" data-name="decoration/body-recovery-ring">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoveryRing} />
          </div>
          <div className="absolute left-[126px] size-[92px] top-[42px]" data-node-id="88:33" data-name="decoration/body-recovery-glow">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoveryGlow} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[16px] text-[#66574a] text-[12px] top-[13px] whitespace-nowrap" data-node-id="88:34">
            身体与精力
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[28px] leading-[34px] left-[16px] text-[#2e2621] text-[20px] top-[47px] w-[100px]" data-node-id="88:35">
            待记录
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[16px] leading-[14px] left-[16px] text-[#7a6957] text-[10px] top-[82px] w-[138px]" data-node-id="88:36">
            约 10 秒 · 快速完成
          </p>
        </div>
        <div className="absolute bg-gradient-to-r from-[#f8f2e9] h-[108px] left-[186px] overflow-clip rounded-[20px] to-[#f4eadb] top-0 w-[175px]" data-node-id="88:37" data-name="card/sleep">
          <div className="absolute left-[124px] size-[42px] top-[14px]" data-node-id="88:38" data-name="decoration/sleep-crescent">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationSleepCrescent} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[16px] text-[#57665c] text-[12px] top-[13px] whitespace-nowrap" data-node-id="88:40">
            昨夜休息
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[28px] leading-[34px] left-[16px] text-[#2b2926] text-[20px] top-[47px] w-[100px]" data-node-id="88:41">
            待记录
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[16px] leading-[14px] left-[16px] text-[#66786b] text-[10px] top-[82px] w-[138px]" data-node-id="88:42">
            补充昨夜休息情况
          </p>
        </div>
        <div className="absolute bg-gradient-to-r from-[#fbece8] h-[64px] left-0 overflow-clip rounded-[20px] to-[#f7e3df] top-[120px] w-[361px]" data-node-id="88:43" data-name="card/mood-checkin">
          <div className="absolute h-[64px] left-[126px] top-0 w-[210px]" data-node-id="88:44" data-name="decoration/mood-wave">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationMoodWave} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium h-[18px] leading-[16px] left-[16px] text-[#755e59] text-[11px] top-[11px] w-[60px]" data-node-id="88:47">
            今日心情
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[20px] leading-[18px] left-[16px] text-[#332926] text-[13px] top-[32px] w-[110px]" data-node-id="88:48">
            今天感觉怎么样？
          </p>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[172px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="88:50" data-name="choice/mood-low">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="88:51">
              不太好
            </p>
          </div>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[232px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="88:52" data-name="choice/mood-neutral">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="88:53">
              一般
            </p>
          </div>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[292px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="88:54" data-name="choice/mood-good">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="88:55">
              不错
            </p>
          </div>
        </div>
      </div>
      <div className="content-stretch flex h-[32px] items-center overflow-clip relative shrink-0 w-[361px]" data-node-id="88:56" data-name="section/expert-support-header">
        <p className="[word-break:break-word] font-['Noto_Sans_SC:Bold'] font-bold leading-[28px] relative shrink-0 text-[#292424] text-[18px] whitespace-nowrap" data-node-id="88:57">
          专家陪伴计划
        </p>
      </div>
      <div className="bg-gradient-to-r border border-[rgba(228,221,213,0.38)] border-solid from-[#fffdf9] h-[88px] overflow-clip relative rounded-[18px] shrink-0 to-[#eaf4ef] via-[#f7f6ee] via-[56%] w-full" data-node-id="88:58" data-name="card/expert-support">
        <div className="absolute left-[285px] size-[112px] top-[-29px]" data-node-id="88:59" data-name="decoration/expert-support-halo">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationExpertSupportHalo} />
        </div>
        <div className="absolute h-[65px] left-[289px] top-[6px] w-[58px]" data-node-id="88:60" data-name="decoration/expert-support-leaves">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationExpertSupportLeaves} />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[21px] leading-[22px] left-[73px] text-[#2b2624] text-[14px] top-[17px] w-[220px]" data-node-id="88:63">
          让专业的人，陪你把问题解决
        </p>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[28px] leading-[13px] left-[73px] text-[#80736e] text-[10px] top-[42px] w-[235px]" data-node-id="88:64">
          专家 + AI 持续服务，从分析问题到跟进改善，全程有人陪
        </p>
        <div className="absolute border-[1.5px] border-[rgba(255,255,255,0.92)] border-solid left-[15px] rounded-[14px] size-[44px] top-[21px]" data-node-id="88:68" data-name="icon-tile/expert-support">
          <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none rounded-[14px] size-full" src={imgIconTileExpertSupport} />
        </div>
        <div className="absolute left-[324px] size-[20px] top-[33px]" data-node-id="88:73" data-name="icon/expert-support-arrow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconExpertSupportArrow} />
        </div>
      </div>
      <div className="bg-[rgba(255,253,251,0.99)] content-stretch flex h-[74px] items-center justify-between overflow-clip pb-[5px] pt-[7px] px-[5px] relative rounded-[22px] shrink-0 w-full" data-node-id="88:75" data-name="navigation/bottom">
        <div className="absolute bg-[rgba(234,227,235,0.9)] h-px left-0 top-0 w-[361px]" data-node-id="88:76" data-name="divider/top" />
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="88:77" data-name="tab/me-active">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="88:78" data-name="slot/icon">
            <div className="bg-[#f0e7fc] content-stretch flex h-[34px] items-center justify-center overflow-clip relative rounded-[14px] shrink-0 w-[42px]" data-node-id="88:79" data-name="state/active-tile">
              <div className="relative shrink-0 size-[24px]" data-node-id="88:80" data-name="icon/me">
                <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconMe} />
              </div>
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#824cc8] text-[11px] text-center w-[60px]" data-node-id="88:83">
            Me
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="88:84" data-name="tab/baby">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="88:85" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="88:86" data-name="icon/baby">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconBaby} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="88:93">
            Baby
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="88:94" data-name="tab/cozymate">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="88:95" data-name="slot/icon">
            <div className="relative shrink-0 size-[36px]" data-node-id="88:96" data-name="avatar/cozymate-nav">
              <img alt="" className="absolute block inset-0 max-w-none size-full" height="36" src={imgAvatarCozymateNav} width="36" />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="88:97">
            Cozymate
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="88:98" data-name="tab/schedule">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="88:99" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="88:100" data-name="icon/schedule">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconSchedule} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="88:103">
            Schedule
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="88:104" data-name="tab/more">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="88:105" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="88:106" data-name="icon/more">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconMore} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="88:110">
            More
          </p>
        </div>
      </div>
    </div>
  );
}
SUPER CRITICAL: The generated React+Tailwind code MUST be converted to match the target project's technology stack and styling system.
1. Analyze the target codebase to identify: technology stack, styling approach, component patterns, and design tokens
2. Convert React syntax to the target framework/library
3. Transform all Tailwind classes to the target styling system while preserving exact visual design
4. Follow the project's existing patterns and conventions
DO NOT install any Tailwind as a dependency unless the user instructs you to do so.

Node ids have been added to the code as data attributes, e.g. `data-node-id="1:2"`.
Images and SVGs will be stored as constants, e.g. const image = 'https://www.figma.com/api/mcp/asset/550e8400-e29b-41d4-a716-446655440000.png'. These constants will be used in the code as the source for the image, ex: <img src={image} />. Image assets are stored on a remote server for 7 days and can be fetched using the provided URLs until they expire.
