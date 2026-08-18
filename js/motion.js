(function(){
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveData=navigator.connection?.saveData===true;
  const lowMemory=Number(navigator.deviceMemory||8)<=4;
  const lowCpu=Number(navigator.hardwareConcurrency||8)<=4;
  const full=!reduced&&!saveData&&!lowMemory&&!lowCpu;
  document.documentElement.classList.add(full?'aura-motion-full':'aura-motion-lite');
  if(!full||!('IntersectionObserver'in window))return;
  const targets=document.querySelectorAll('.welcome-panel,.next-victory,.moments-section,.aura-foundation,.metrics-grid,.evolution-panel,.dashboard-grid,.trajectory-message,.ranking-hero,.ranking-layout,.habits-hero,.mission-strip,.habits-toolbar,.community-center,.projects-hero,.projects-workspace,.people-hero,.people-toolbar,.people-grid,.identity-hero,.identity-card,.chat-shell');
  const observer=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){entry.target.classList.add('is-visible');observer.unobserve(entry.target)}}),{rootMargin:'0px 0px -5% 0px',threshold:.06});
  targets.forEach((target,index)=>{target.classList.add('motion-reveal');target.style.transitionDelay=`${Math.min(index%4,3)*35}ms`;observer.observe(target)});
})();
