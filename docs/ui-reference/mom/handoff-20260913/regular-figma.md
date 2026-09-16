const imgAssetCozymateAvatar = "https://www.figma.com/api/mcp/asset/c3fa4f6d-e2eb-4738-a9c4-cc516537eab6.png";
const imgIconTileExpertSupport = "https://www.figma.com/api/mcp/asset/366170a2-4802-426d-b447-a97e577992f5.png";
const imgAvatarCozymateNav = "https://www.figma.com/api/mcp/asset/bd681dc4-dbff-4c04-aa86-e35942ac54ab.png";
const imgDecorationAiSparkle = "https://www.figma.com/api/mcp/asset/6b10b84f-234d-4910-9552-cd2a0770b706.svg";
const imgDecorationAiBlushGlow = "https://www.figma.com/api/mcp/asset/e2fac8ef-eea4-4c55-b113-60a9980e039b.svg";
const imgDecorationAiLilacGlow = "https://www.figma.com/api/mcp/asset/4771bdd0-b7e0-4ee4-b880-c1bdfdf1ddd7.svg";
const imgDecorationLactationDroplet = "https://www.figma.com/api/mcp/asset/2913760c-18a6-4c52-8b0a-9dbca1bdf187.svg";
const imgDecorationBodyRecoverySoftDot = "https://www.figma.com/api/mcp/asset/9f634820-a664-4f78-9980-67cf4bf12cd7.svg";
const imgDecorationBodyRecoveryRing = "https://www.figma.com/api/mcp/asset/ca73cf9d-fe29-4456-9f95-aaeac081e771.svg";
const imgDecorationBodyRecoveryGlow = "https://www.figma.com/api/mcp/asset/755f70b5-5688-4349-a642-3b9111c8d6f0.svg";
const imgDecorationSleepCrescent = "https://www.figma.com/api/mcp/asset/4810d320-8fd5-4368-b9f7-7d427267ee78.svg";
const imgDecorationMoodWave = "https://www.figma.com/api/mcp/asset/55a21bec-16bb-4111-8aac-b2311ab4b195.svg";
const imgDecorationExpertSupportHalo = "https://www.figma.com/api/mcp/asset/347733e3-de8d-4bec-aeab-2db694c9833e.svg";
const imgDecorationExpertSupportLeaves = "https://www.figma.com/api/mcp/asset/0e558239-ba3e-413d-9c16-b58c1209e9b9.svg";
const imgIconExpertSupportArrow = "https://www.figma.com/api/mcp/asset/47cd5cda-3c58-4d94-97ce-9c55c89733e1.svg";
const imgIconMe = "https://www.figma.com/api/mcp/asset/006b24b0-748b-4815-b2f4-09820f06b330.svg";
const imgIconBaby = "https://www.figma.com/api/mcp/asset/774ccf21-3aa4-4b29-8b0a-9de9a426177b.svg";
const imgIconSchedule = "https://www.figma.com/api/mcp/asset/15a8bcce-af3c-4e0c-b597-32181c2661f5.svg";
const imgIconMore = "https://www.figma.com/api/mcp/asset/8bb371d5-50ac-4c65-915d-c6c70233707b.svg";

export default function ScreenMomHome() {
  return (
    <div className="bg-[#fbf8f4] content-stretch flex flex-col gap-[14px] items-start pt-[18px] px-[16px] relative size-full" data-node-id="19:2" data-name="screen/mom-home">
      <div className="[word-break:break-word] content-stretch flex h-[58px] items-center justify-between overflow-clip relative shrink-0 w-full whitespace-nowrap" data-node-id="19:3" data-name="section/header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold leading-[34px] relative shrink-0 text-[#292424] text-[20px]" data-node-id="19:4">
          下午好，Mia
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] relative shrink-0 text-[#756966] text-[12px]" data-node-id="19:5">
          产后第 21 天 · 恢复建立期
        </p>
      </div>
      <div className="bg-gradient-to-r from-[#fff3ee] h-[138px] overflow-clip relative rounded-[22px] shrink-0 to-[#ead9fb] via-[#f8f0f7] via-[48%] w-full" data-node-id="19:6" data-name="card/ai-insight">
        <div className="absolute left-[314px] size-[20px] top-[74px]" data-node-id="83:4" data-name="decoration/ai-sparkle">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiSparkle} />
        </div>
        <div className="absolute h-[92px] left-[-42px] top-[88px] w-[150px]" data-node-id="83:3" data-name="decoration/ai-blush-glow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiBlushGlow} />
        </div>
        <div className="absolute left-[270px] size-[128px] top-[-36px]" data-node-id="83:2" data-name="decoration/ai-lilac-glow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationAiLilacGlow} />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[18px] text-[#665b8a] text-[12px] top-[12px] w-[190px]" data-node-id="21:2">
          Cozymate · 基于你的近期记录
        </p>
        <div className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[50px] leading-[0] left-[18px] text-[#292733] text-[16px] top-[34px] w-[240px]" data-node-id="21:3">
          <p className="leading-[25px] mb-0">恢复不是直线，</p>
          <p className="leading-[25px]">变化本身也值得被看见</p>
        </div>
        <div className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[34px] leading-[0] left-[18px] text-[#706d78] text-[11px] top-[90px] w-[284px]" data-node-id="21:4">
          <p className="leading-[17px] mb-0">体力、不适和照护感受每天不同。</p>
          <p className="leading-[17px]">持续记录，AI 会帮你判断恢复趋势。</p>
        </div>
        <div className="absolute left-[293px] size-[50px] top-[12px]" data-node-id="21:5" data-name="asset/cozymate-avatar">
          <img alt="" className="absolute block inset-0 max-w-none size-full" height="50" src={imgAssetCozymateAvatar} width="50" />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[322px] text-[#665b8a] text-[22px] top-[101px] whitespace-nowrap" data-node-id="21:6">
          →
        </p>
      </div>
      <div className="[word-break:break-word] content-stretch flex h-[30px] items-center justify-between overflow-clip relative shrink-0 w-[361px]" data-node-id="30:2" data-name="section/lactation-header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold leading-[28px] relative shrink-0 text-[#2b2624] text-[18px] whitespace-nowrap" data-node-id="30:3">
          今日泌乳
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium leading-[18px] relative shrink-0 text-[#ab476b] text-[12px] whitespace-pre" data-node-id="30:4">{`查看记录  ›`}</p>
      </div>
      <div className="bg-gradient-to-r content-stretch flex flex-col from-[#fbece8] gap-[4px] h-[132px] items-start overflow-clip pb-[10px] pt-[12px] px-[16px] relative rounded-[22px] shrink-0 to-[#f7e5e1] w-full" data-node-id="21:7" data-name="card/lactation-empty">
        <div className="absolute h-[49px] left-[302px] top-[4px] w-[42px]" data-node-id="74:2" data-name="decoration/lactation-droplet">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationLactationDroplet} />
        </div>
        <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[29px] relative shrink-0 text-[#2e2424] text-[18px] whitespace-nowrap" data-node-id="21:9">
          暂未记录
        </p>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal leading-[13px] left-[16px] text-[#7a6663] text-[10px] top-[104px] w-[172px]" data-node-id="21:12">
          记录后，AI 会持续判断奶量与供需趋势
        </p>
        <div className="absolute bg-[#b54f78] content-stretch flex h-[38px] items-center justify-center left-[16px] overflow-clip rounded-[19px] top-[54px] w-[329px]" data-node-id="21:10" data-name="button/record-lactation">
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Bold'] font-bold leading-[normal] relative shrink-0 text-[14px] text-white whitespace-nowrap" data-node-id="21:11">
            ＋ 记录一次泌乳
          </p>
        </div>
      </div>
      <div className="[word-break:break-word] content-stretch flex h-[32px] items-center justify-between leading-[normal] overflow-clip relative shrink-0 w-full" data-node-id="21:13" data-name="section/recovery-header">
        <p className="font-['Noto_Sans_SC:Bold'] font-bold relative shrink-0 text-[#292424] text-[18px] whitespace-nowrap" data-node-id="21:14">
          今日状态
        </p>
        <p className="font-['Noto_Sans_SC:Medium'] font-medium relative shrink-0 text-[#a65470] text-[12px] whitespace-pre" data-node-id="21:15">{`今日完成 2/3 · 继续记录  ›`}</p>
      </div>
      <div className="h-[184px] overflow-clip relative shrink-0 w-full" data-node-id="21:16" data-name="group/recovery-status">
        <div className="absolute bg-gradient-to-r from-[#f7f1e7] h-[108px] left-0 overflow-clip rounded-[20px] to-[#f2e9db] top-0 w-[175px]" data-node-id="22:2" data-name="card/body-recovery">
          <div className="absolute left-[119px] size-[28px] top-[77px]" data-node-id="83:7" data-name="decoration/body-recovery-soft-dot">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoverySoftDot} />
          </div>
          <div className="absolute left-[137px] size-[76px] top-[53px]" data-node-id="83:6" data-name="decoration/body-recovery-ring">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoveryRing} />
          </div>
          <div className="absolute left-[126px] size-[92px] top-[42px]" data-node-id="74:6" data-name="decoration/body-recovery-glow">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationBodyRecoveryGlow} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[16px] text-[#66574a] text-[12px] top-[13px] whitespace-nowrap" data-node-id="22:3">
            身体与精力
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[34px] leading-[34px] left-[16px] text-[#2e2621] text-[26px] top-[43px] w-[90px]" data-node-id="22:4">
            70%
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[16px] leading-[14px] left-[16px] text-[#7a6957] text-[10px] top-[82px] w-[138px]" data-node-id="22:5">
            有力气 · 暂无不适
          </p>
        </div>
        <div className="absolute bg-gradient-to-r from-[#f8f2e9] h-[108px] left-[186px] overflow-clip rounded-[20px] to-[#f4eadb] top-0 w-[175px]" data-node-id="22:6" data-name="card/sleep">
          <div className="absolute left-[124px] size-[42px] top-[14px]" data-node-id="74:4" data-name="decoration/sleep-crescent">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationSleepCrescent} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium leading-[normal] left-[16px] text-[#57665c] text-[12px] top-[13px] whitespace-nowrap" data-node-id="22:7">
            昨夜休息
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[34px] leading-[34px] left-[16px] text-[#2b2926] text-[24px] top-[43px] w-[130px]" data-node-id="22:8">
            4–5 小时
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[16px] leading-[14px] left-[16px] text-[#66786b] text-[10px] top-[82px] w-[138px]" data-node-id="22:9">
            比前一晚少 1 小时
          </p>
        </div>
        <div className="absolute bg-gradient-to-r from-[#fbece8] h-[64px] left-0 overflow-clip rounded-[20px] to-[#f7e3df] top-[120px] w-[361px]" data-node-id="22:10" data-name="card/mood-checkin">
          <div className="absolute h-[64px] left-[126px] top-0 w-[210px]" data-node-id="83:8" data-name="decoration/mood-wave">
            <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationMoodWave} />
          </div>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Medium'] font-medium h-[18px] leading-[16px] left-[16px] text-[#755e59] text-[11px] top-[11px] w-[60px]" data-node-id="22:11">
            今日心情
          </p>
          <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[20px] leading-[18px] left-[16px] text-[#332926] text-[13px] top-[32px] w-[110px]" data-node-id="22:12">
            今天感觉怎么样？
          </p>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[172px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="31:2" data-name="choice/mood-low">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="31:3">
              不太好
            </p>
          </div>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[232px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="31:4" data-name="choice/mood-neutral">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="31:5">
              一般
            </p>
          </div>
          <div className="absolute bg-[rgba(255,249,247,0.96)] border border-[rgba(235,207,201,0.58)] border-solid content-stretch flex h-[28px] items-center justify-center left-[292px] overflow-clip rounded-[14px] top-[18px] w-[53px]" data-node-id="31:6" data-name="choice/mood-good">
            <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium leading-[14px] relative shrink-0 text-[#85595e] text-[10px] whitespace-nowrap" data-node-id="31:7">
              不错
            </p>
          </div>
        </div>
      </div>
      <div className="content-stretch flex h-[32px] items-center overflow-clip relative shrink-0 w-[361px]" data-node-id="58:2" data-name="section/expert-support-header">
        <p className="[word-break:break-word] font-['Noto_Sans_SC:Bold'] font-bold leading-[28px] relative shrink-0 text-[#292424] text-[18px] whitespace-nowrap" data-node-id="61:2">
          专家陪伴计划
        </p>
      </div>
      <div className="bg-gradient-to-r border border-[rgba(228,221,213,0.38)] border-solid from-[#fffdf9] h-[88px] overflow-clip relative rounded-[18px] shrink-0 to-[#eaf4ef] via-[#f7f6ee] via-[56%] w-full" data-node-id="58:3" data-name="card/expert-support">
        <div className="absolute left-[285px] size-[112px] top-[-29px]" data-node-id="77:2" data-name="decoration/expert-support-halo">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationExpertSupportHalo} />
        </div>
        <div className="absolute h-[65px] left-[289px] top-[6px] w-[58px]" data-node-id="77:3" data-name="decoration/expert-support-leaves">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgDecorationExpertSupportLeaves} />
        </div>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Bold'] font-bold h-[21px] leading-[22px] left-[73px] text-[#2b2624] text-[14px] top-[17px] w-[220px]" data-node-id="58:5">
          让专业的人，陪你把问题解决
        </p>
        <p className="[word-break:break-word] absolute font-['Noto_Sans_SC:Regular'] font-normal h-[28px] leading-[13px] left-[73px] text-[#80736e] text-[10px] top-[42px] w-[235px]" data-node-id="58:6">
          专家 + AI 持续服务，从分析问题到跟进改善，全程有人陪
        </p>
        <div className="absolute border-[1.5px] border-[rgba(255,255,255,0.92)] border-solid left-[15px] rounded-[14px] size-[44px] top-[21px]" data-node-id="65:13" data-name="icon-tile/expert-support">
          <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none rounded-[14px] size-full" src={imgIconTileExpertSupport} />
        </div>
        <div className="absolute left-[324px] size-[20px] top-[33px]" data-node-id="65:18" data-name="icon/expert-support-arrow">
          <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconExpertSupportArrow} />
        </div>
      </div>
      <div className="bg-[rgba(255,253,251,0.99)] content-stretch flex h-[74px] items-center justify-between overflow-clip pb-[5px] pt-[7px] px-[5px] relative rounded-[22px] shrink-0 w-full" data-node-id="24:2" data-name="navigation/bottom">
        <div className="absolute bg-[rgba(234,227,235,0.9)] h-px left-0 top-0 w-[361px]" data-node-id="86:2" data-name="divider/top" />
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="86:3" data-name="tab/me-active">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="86:4" data-name="slot/icon">
            <div className="bg-[#f0e7fc] content-stretch flex h-[34px] items-center justify-center overflow-clip relative rounded-[14px] shrink-0 w-[42px]" data-node-id="86:5" data-name="state/active-tile">
              <div className="relative shrink-0 size-[24px]" data-node-id="86:6" data-name="icon/me">
                <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconMe} />
              </div>
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#824cc8] text-[11px] text-center w-[60px]" data-node-id="86:9">
            Me
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="86:10" data-name="tab/baby">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="86:11" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="86:12" data-name="icon/baby">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconBaby} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="86:19">
            Baby
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="86:20" data-name="tab/cozymate">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="86:21" data-name="slot/icon">
            <div className="relative shrink-0 size-[36px]" data-node-id="86:22" data-name="avatar/cozymate-nav">
              <img alt="" className="absolute block inset-0 max-w-none size-full" height="36" src={imgAvatarCozymateNav} width="36" />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="86:23">
            Cozymate
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="86:24" data-name="tab/schedule">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="86:25" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="86:26" data-name="icon/schedule">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconSchedule} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="86:29">
            Schedule
          </p>
        </div>
        <div className="content-stretch flex flex-col gap-[2px] items-center justify-center overflow-clip relative shrink-0 size-[60px]" data-node-id="86:30" data-name="tab/more">
          <div className="content-stretch flex h-[38px] items-center justify-center overflow-clip relative shrink-0 w-[44px]" data-node-id="86:31" data-name="slot/icon">
            <div className="relative shrink-0 size-[28px]" data-node-id="86:32" data-name="icon/more">
              <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgIconMore} />
            </div>
          </div>
          <p className="[word-break:break-word] font-['Noto_Sans_SC:Medium'] font-medium h-[16px] leading-[normal] relative shrink-0 text-[#91868d] text-[11px] text-center w-[60px]" data-node-id="86:36">
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
