import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useShallow } from 'zustand/react/shallow';
import { Plus, Trash2 } from 'lucide-react';
import { toast } from 'react-hot-toast';

import { use__Entity__Store } from '../store/__ENTITY__Store';
import { usePermissionStore } from '../store/permissionStore';
import { useAuthStore } from '../store/authStore';
import { Button, Modal, Table, Thead, Tbody, Tr, Th, Td, SearchFilter } from '../components/ui';
import PageHeader from '../components/PageHeader';
import Pagination from '../components/Pagination';
import ErrorState from '../components/ErrorState';
import { TableRowSkeleton } from '../components/Skeletons';
import { extractApiErrorMessage } from '../utils/apiError';
import styles from '../styles/__Entities__.module.css';

const PER_PAGE = 10;

const __Entities__ = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const { items, pagination, isLoading, error, fetchAll, remove } = use__Entity__Store(
    useShallow((s) => ({
      items: s.items,
      pagination: s.pagination,
      isLoading: s.isLoading,
      error: s.error,
      fetchAll: s.fetchAll,
      remove: s.remove,
    }))
  );

  const role = useAuthStore((s) => s.user?.role) ?? 'user';
  const has = usePermissionStore((s) => s.has);
  const can = (permission) => has(permission, role);

  const [search, setSearch] = useState(searchParams.get('search') || '');
  const [page, setPage] = useState(parseInt(searchParams.get('page')) || 1);

  const [deleteTarget, setDeleteTarget] = useState(null);
  const [deleting, setDeleting] = useState(false);

  // Debounced fetch. The cleanup is what makes it a debounce — do not remove it.
  useEffect(() => {
    const timer = setTimeout(() => {
      fetchAll({ page, per_page: PER_PAGE, ...(search ? { search } : {}) });
    }, 500);
    return () => clearTimeout(timer);
  }, [fetchAll, page, search]);

  // Mirror view state into the URL so a reload and a shared link reproduce the view.
  useEffect(() => {
    const params = new URLSearchParams();
    if (search) params.set('search', search);
    if (page > 1) params.set('page', page);
    setSearchParams(params, { replace: true });
  }, [search, page, setSearchParams]);

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      setDeleting(true);
      await remove(deleteTarget);
      setDeleteTarget(null);
      toast.success('__Entity__ deleted');
    } catch (err) {
      toast.error(extractApiErrorMessage(err, 'Could not delete __ENTITY__'));
    } finally {
      setDeleting(false);
    }
  };

  // Error is checked before loading: a failure that also cleared isLoading
  // would otherwise render a blank page.
  if (error) {
    return <ErrorState message={error} onRetry={() => fetchAll({ page, per_page: PER_PAGE })} />;
  }

  return (
    <div className={styles.page}>
      <PageHeader
        title="__Entities__"
        actions={can('__PERMISSION__.create') && (
          <Button icon={Plus} onClick={() => navigate('/__ENTITIES__/new')}>Add __Entity__</Button>
        )}
      />

      <SearchFilter
        value={search}
        placeholder="Search __ENTITIES__…"
        onChange={(value) => { setSearch(value); setPage(1); }}
      />

      <Table>
        <Thead>
          <Tr><Th>Name</Th><Th>Created</Th><Th /></Tr>
        </Thead>
        <Tbody>
          {isLoading
            ? <TableRowSkeleton columns={3} rows={8} />
            : items.map((item) => (
                <Tr key={item.id} onClick={() => navigate(`/__ENTITIES__/${item.id}`)}>
                  <Td>{item.name}</Td>
                  <Td>{item.created_at}</Td>
                  <Td>
                    {can('__PERMISSION__.delete') && (
                      <Button
                        variant="ghost"
                        icon={Trash2}
                        aria-label={`Delete ${item.name}`}
                        onClick={(e) => { e.stopPropagation(); setDeleteTarget(item.id); }}
                      />
                    )}
                  </Td>
                </Tr>
              ))}
        </Tbody>
      </Table>

      {!isLoading && items.length === 0 && (
        <div className={styles.empty}>No __ENTITIES__ found.</div>
      )}

      <Pagination
        currentPage={pagination?.current_page ?? page}
        lastPage={pagination?.last_page ?? 1}
        total={pagination?.total}
        perPage={pagination?.per_page ?? PER_PAGE}
        onPageChange={(next) => { setPage(next); window.scrollTo({ top: 0, behavior: 'smooth' }); }}
      />

      <Modal
        isOpen={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        title="Delete __ENTITY__?"
      >
        <p className={styles.confirmText}>This cannot be undone.</p>
        <Button variant="danger" isLoading={deleting} onClick={handleDelete}>Delete</Button>
      </Modal>
    </div>
  );
};

export default __Entities__;
