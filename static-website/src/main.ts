import './style.css'
import logo from '/logo.png'

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <div>
    <a href="https://internetcomputer.org" target="_blank">
      <img src="${logo}" class="logo" alt="DFINITY logo" />
    </a>
    <p class="read-the-docs">
      Congrats! You've deployed static assets to a canister running on ICP.
    </p>
  </div>
`
