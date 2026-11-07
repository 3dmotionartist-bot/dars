import type { Metadata } from 'next';
import ContactForm from '@/components/ContactForm';
import Icon from '@/components/Icon';
import { SectionHead } from '@/components/Ui';
import { WHATSAPP } from '@/lib/data';
import { getDict, type Lang } from '@/lib/i18n';

export function generateMetadata({ params }: { params: { lang: Lang } }): Metadata {
  return { title: getDict(params.lang).contact.title };
}

export default function Contact({ params }: { params: { lang: Lang } }) {
  const d = getDict(params.lang).contact;
  return (
    <section className="section page-top">
      <div className="container grid-2">
        <div>
          <SectionHead title={d.title} subtitle={d.subtitle} />
          <a className="card contact-row" href={WHATSAPP}>
            <span className="contact-icon wa"><Icon name="chat" /></span>
            <span><b>{d.whatsapp}</b><small dir="ltr">+963 000 000 000</small></span>
          </a>
          <a className="card contact-row" href="mailto:hello@dars.app">
            <span className="contact-icon"><Icon name="mail" /></span>
            <span><b>{d.emailUs}</b><small dir="ltr">hello@dars.app</small></span>
          </a>
        </div>
        <ContactForm lang={params.lang} />
      </div>
    </section>
  );
}
