document.addEventListener('DOMContentLoaded', () => {
  initMobileNav();
  initCopyButtons();
  initScrollSpy();
  initDynamicYear();
});

function initMobileNav() {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.querySelector('.nav-menu');

  if (!toggle || !menu) return;

  toggle.addEventListener('click', () => {
    const isExpanded = toggle.getAttribute('aria-expanded') === 'true';
    toggle.setAttribute('aria-expanded', String(!isExpanded));
    menu.setAttribute('aria-expanded', String(!isExpanded));
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
      toggle.setAttribute('aria-expanded', 'false');
      menu.setAttribute('aria-expanded', 'false');
      toggle.focus();
    }
  });
}

function initCopyButtons() {
  const statusRegion = document.getElementById('aria-status');

  document.querySelectorAll('.copy-btn').forEach((button) => {
    button.addEventListener('click', async () => {
      const codeBlock = button.closest('.code-card')?.querySelector('pre code');
      if (!codeBlock) return;

      const codeText = codeBlock.textContent || '';

      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(codeText);
        } else {
          fallbackCopyText(codeText);
        }

        const originalText = button.textContent;
        button.textContent = 'Copied!';
        button.setAttribute('aria-label', 'Copied to clipboard');

        if (statusRegion) {
          statusRegion.textContent = 'Code copied to clipboard';
        }

        setTimeout(() => {
          button.textContent = originalText;
          button.setAttribute('aria-label', 'Copy code to clipboard');
          if (statusRegion) {
            statusRegion.textContent = '';
          }
        }, 2000);
      } catch (error) {
        button.textContent = 'Failed';
        setTimeout(() => {
          button.textContent = 'Copy';
        }, 2000);
      }
    });
  });
}

function fallbackCopyText(text) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand('copy');
  document.body.removeChild(textarea);
}

function initScrollSpy() {
  const tocLinks = document.querySelectorAll('.toc-link');
  if (tocLinks.length === 0) return;

  const headings = Array.from(tocLinks)
    .map((link) => {
      const targetId = link.getAttribute('href')?.replace('#', '');
      return targetId ? document.getElementById(targetId) : null;
    })
    .filter(Boolean);

  if (headings.length === 0) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute('id');
          tocLinks.forEach((link) => {
            const match = link.getAttribute('href') === `#${id}`;
            link.classList.toggle('is-active', match);
            if (match) {
              link.setAttribute('aria-current', 'true');
            } else {
              link.removeAttribute('aria-current');
            }
          });
        }
      });
    },
    { rootMargin: '-20% 0px -70% 0px' }
  );

  headings.forEach((heading) => observer.observe(heading));
}

function initDynamicYear() {
  const currentYear = String(new Date().getFullYear());
  document.querySelectorAll('.current-year').forEach((element) => {
    element.textContent = currentYear;
  });
}
