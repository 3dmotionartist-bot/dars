import Link from 'next/link';

export default function NotFound() {
  return (
    <section className="section page-top">
      <div className="container center">
        <h1>404</h1>
        <p className="lead">الصفحة غير موجودة · Page not found</p>
        <Link className="btn btn-primary" href="/ar/">درس · Dars</Link>
      </div>
    </section>
  );
}
